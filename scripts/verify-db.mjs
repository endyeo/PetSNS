import { readFile, readdir, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { PGlite } from '../build/db-verification/node_modules/@electric-sql/pglite/dist/index.js';

const root = new URL('../', import.meta.url);
const migrationDirectory = new URL('supabase/migrations/', root);
const migrationFiles = (await readdir(migrationDirectory)).filter(name => name.endsWith('.sql')).sort();
const migrations = await Promise.all(migrationFiles.map(name => readFile(new URL(name, migrationDirectory), 'utf8')));
const testFiles = ['profiles_and_pets.sql', 'memory_days.sql', 'memory_photos.sql'];
const tests = await Promise.all(testFiles.map(name => readFile(new URL(`supabase/tests/${name}`, root), 'utf8')));
const report = { engine: 'PGlite 0.3.14 PostgreSQL with Auth schema fixtures', scope: 'Local SQL only; no Supabase Auth gateway', migrations: migrationFiles, runs: [] };

for (let run = 1; run <= 2; run++) {
  const db = await PGlite.create();
  try {
    // These fixtures model DB roles/claims only; they do not verify Supabase Auth.
    await db.exec(`
      create role anon nologin;
      create role authenticated nologin;
      create role service_role nologin bypassrls;
      create schema auth;
      create table auth.users (id uuid primary key);
      create function auth.uid() returns uuid language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
      $$;
      grant usage on schema public, auth to anon, authenticated;
      create schema storage;
      create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
      create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,metadata jsonb,unique(bucket_id,name));
      alter table storage.objects enable row level security;
      grant usage on schema storage to anon,authenticated;
      grant select,insert,update,delete on storage.objects to anon,authenticated;
      -- Model the existing Supabase bootstrap function's default EXECUTE grant.
      create function public.rls_auto_enable() returns event_trigger
        language plpgsql security definer as $$ begin return; end; $$;
      create event trigger ensure_rls on ddl_command_end
        execute function public.rls_auto_enable();
    `);
    for (const migration of migrations) await db.exec(migration);
    const results = [];
    for (const suite of tests) results.push(...await db.exec(suite));
    const passed = results.flatMap(result => result.rows)
      .flatMap(row => Object.values(row))
      .filter(value => typeof value === 'string' && value.startsWith('PASS: '));
    if (passed.length === 0) throw new Error('No assertions executed');
    const remaining = await db.query('select count(*)::integer as count from auth.users');
    if (remaining.rows[0].count !== 0) throw new Error('SQL fixtures were not rolled back');
    passed.push('PASS: all Auth fixtures rolled back');
    report.runs.push({ run, status: 'PASS', passed: passed.length, assertions: passed });
    console.log(`PASS: fresh database ${run}, ${passed.length} assertions`);
  } finally {
    await db.close();
  }
}
await mkdir(new URL('build/db-verification/', root), { recursive: true });
await writeFile(new URL('build/db-verification/results.json', root), `${JSON.stringify(report, null, 2)}\n`);
console.log(`Evidence: ${fileURLToPath(new URL('build/db-verification/results.json', root))}`);
