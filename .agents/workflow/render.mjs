import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {dirname, resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {validateReport} from './model.mjs';

export function digest(value) { return createHash('sha256').update(typeof value === 'string' ? value : JSON.stringify(value)).digest('hex'); }
export function seal(input) {
  const d = structuredClone(input);
  delete d.reportHash;
  for (const v of d.versions || []) {
    delete v.versionHash;
    for (const c of v.decisions) { delete c.proposalHash; c.proposalHash = digest(c); }
    v.versionHash = digest(v);
  }
  validateReport(d);
  d.reportHash = digest(d);
  return d;
}
export function render(input) {
  const d = seal(input), root = dirname(fileURLToPath(import.meta.url));
  const model = readFileSync(join(root, 'model.mjs'), 'utf8').replace(/^export /gm, '');
  const ui = readFileSync(join(root, 'review.js'), 'utf8');
  const css = readFileSync(join(root, 'review.css'), 'utf8');
  const json = JSON.stringify(d).replace(/</g, '\\u003c');
  return `<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>PetSNS 작업 검토</title><style>${css}</style><body><header><small>PetSNS · 독립 개발 워크플로</small><h1 id="title"></h1><p id="identity"></p></header><nav id="tabs" aria-label="보고서 탭"></nav><main id="content"></main><footer><button id="save">회차 저장·JSON 다운로드</button><label class="button">승인 JSON 가져오기<input id="import" type="file" accept="application/json"></label><p id="message" role="status"></p><small>선택은 이 브라우저에 저장됩니다. 이동 전 JSON을 내려받으세요. 저장 실패 시 다운로드를 중단합니다.</small></footer><script id="report-data" type="application/json">${json}</script><script type="module">${model}\n${ui}</script></body></html>`;
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [input, output] = process.argv.slice(2);
    if (!input || !output) throw new Error('Usage: node render.mjs report.json report.html');
    const html = render(JSON.parse(readFileSync(input, 'utf8')));
    mkdirSync(dirname(resolve(output)), {recursive: true});
    writeFileSync(output, html);
    console.log(`Rendered ${output}`);
  } catch (e) { console.error(e.message); process.exitCode = 1; }
}
