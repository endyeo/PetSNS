export const choices = ['approved', 'revise', 'hold'];
export function assert(condition, message) { if (!condition) throw new Error(message); }
export function nonempty(value) { return typeof value === 'string' && value.trim().length > 0; }
export function unique(items, label) {
  assert(Array.isArray(items) && items.length > 0, `${label}: empty`);
  assert(items.every(x => nonempty(x.id) && !['__proto__','constructor','prototype'].includes(x.id)) && new Set(items.map(x => x.id)).size === items.length, `${label}: duplicate/missing/reserved id`);
}
export function safePath(value) {
  return nonempty(value) && (/^https:\/\//i.test(value) || (!/^[a-z]+:|^[/\\]|(?:^|[/\\])\.\.(?:[/\\]|$)/i.test(value) && !/[<>]/.test(value)));
}
export function validateReport(d) {
  assert(d.schemaVersion === 1 && ['plan', 'verification'].includes(d.kind), 'Unsupported report');
  for (const key of ['project', 'taskId', 'title']) assert(nonempty(d[key]), `Missing ${key}`);
  assert(/^[\w.-]+\/[\w.-]+$/.test(d.repository), 'Invalid repository');
  assert(/^[a-f\d]{40}$/i.test(d.revision), 'Expected exact Git revision');
  assert(Array.isArray(d.sources) && d.sources.length > 0, 'Missing source evidence');
  for (const s of d.sources) assert(nonempty(s.path) && /^[a-f\d]{64}$/i.test(s.sha256) && nonempty(s.excerpt), 'Invalid source evidence');
  if (d.kind === 'plan') {
    unique(d.versions, 'versions');
    for (const v of d.versions) {
      assert(nonempty(v.summary), 'Missing version summary');
      unique(v.decisions, 'decisions');
      for (const c of v.decisions) {
        for (const k of ['title', 'proposal', 'reason', 'impact']) assert(nonempty(c[k]), `Missing decision ${k}`);
        assert(typeof c.requiresExplicitApproval === 'boolean', 'Missing approval boundary');
      }
      assert(Array.isArray(v.acceptance) && v.acceptance.length > 0 && v.acceptance.every(nonempty), 'Missing acceptance criteria');
      assert(Array.isArray(v.mockups) && v.mockups.every(x => nonempty(x.title) && safePath(x.path)), 'Unsafe draft path');
    }
  } else {
    unique(d.runs, 'runs');
    for (const r of d.runs) {
      assert(['developer', 'independent-qa'].includes(r.role) && nonempty(r.actor), 'Invalid run actor/role');
      assert(/^[a-f\d]{40}$/i.test(r.revision) && Number.isFinite(Date.parse(r.executedAt)), 'Invalid run revision/time');
      assert(r.environment && /^https?:\/\//.test(r.environment.url) && nonempty(r.environment.viewport) && nonempty(r.environment.build), 'Missing runtime environment');
      unique(r.checks, 'checks');
      assert(Array.isArray(r.issues), 'Missing issues');
      if (r.issues.length) unique(r.issues, 'issues');
      for (const i of r.issues) {
        assert(['minor', 'major', 'critical'].includes(i.severity), 'Invalid severity');
        for (const k of ['title', 'location', 'actual', 'expected']) assert(nonempty(i[k]), `Missing issue ${k}`);
        assert(Array.isArray(i.steps) && i.steps.length && i.steps.every(nonempty), 'Missing reproduction');
      }
      for (const c of r.checks) {
        assert(nonempty(c.title) && nonempty(c.observed) && ['passed', 'failed', 'not-run'].includes(c.result), 'Invalid check');
        assert(Array.isArray(c.evidence) && Array.isArray(c.issueIds), 'Missing check evidence/issue mapping');
        assert(c.result === 'not-run' || c.evidence.length > 0, 'Executed check needs evidence');
        for (const e of c.evidence) {
          assert(['screenshot', 'command', 'source'].includes(e.kind), 'Invalid evidence kind');
          if (e.kind === 'command') assert(nonempty(e.command), 'Missing executed command');
          else assert(safePath(e.path), 'Unsafe evidence path');
          if (e.kind === 'screenshot') assert(Number.isFinite(Date.parse(e.capturedAt)), 'Missing capture time');
        }
        assert(c.issueIds.every(id => r.issues.some(i => i.id === id)), 'Unknown linked issue');
      }
    }
    const current = currentRuns(d);
    const seen = new Map();
    for (const r of current) for (const i of r.issues) {
      assert(!seen.has(i.id) || JSON.stringify(seen.get(i.id)) === JSON.stringify(i), 'Conflicting issue ID');
      seen.set(i.id, i);
    }
  }
  return d;
}
export function currentRuns(d) {
  return ['developer', 'independent-qa'].map(role => d.runs.filter(r => r.role === role && r.revision === d.revision).at(-1)).filter(Boolean);
}
export function readiness(d) {
  const runs = currentRuns(d), issues = [...new Map(runs.flatMap(r => r.issues).map(i => [i.id, i])).values()];
  const reasons = [];
  if (runs.length !== 2) reasons.push('현재 리비전의 개발자 검증과 독립 QA가 모두 필요합니다.');
  if (runs.length === 2 && (runs[0].actor === runs[1].actor || runs[0].environment.build !== runs[1].environment.build)) reasons.push('독립 실행자와 동일 빌드가 필요합니다.');
  for (const r of runs) {
    if (!r.checks.some(c => c.result !== 'not-run' && c.evidence.some(e => e.kind === 'screenshot'))) reasons.push(`${r.id}: 실제 화면 스크린샷이 없습니다.`);
    for (const c of r.checks) {
      if (c.result === 'not-run') reasons.push(`${r.id}/${c.id}: 미실행`);
      if (c.result !== 'not-run' && !c.evidence.some(e => ['screenshot', 'command'].includes(e.kind))) reasons.push(`${r.id}/${c.id}: 실행 증거 없음`);
      if (c.result === 'failed' && (!c.issueIds.length || c.issueIds.some(id => r.issues.find(i => i.id === id).severity !== 'minor'))) reasons.push(`${r.id}/${c.id}: 차단 실패`);
    }
  }
  if (issues.some(i => i.severity !== 'minor')) reasons.push('중대 문제가 남아 있습니다.');
  return {status: reasons.length ? 'blocked' : issues.length ? 'conditional-complete' : 'complete', reasons, issues, runIds: runs.map(r => r.id)};
}
export function validateRound(d, r) {
  assert(r && r.schemaVersion === 1 && r.kind === `${d.kind}-review`, 'Wrong review kind');
  for (const k of ['project', 'taskId', 'repository', 'revision', 'reportHash']) assert(r[k] === d[k], `Stale/wrong ${k}`);
  assert(Number.isInteger(r.round) && r.round > 0 && Number.isFinite(Date.parse(r.reviewedAt)), 'Invalid review round');
  if (d.kind === 'plan') {
    const v = d.versions.find(v => v.id === r.versionId);
    assert(v && r.versionHash === v.versionHash, 'Wrong version fingerprint');
    assert(Array.isArray(r.decisions) && r.decisions.length === v.decisions.length && new Set(r.decisions.map(c => c.id)).size === v.decisions.length, 'Wrong decision set');
    for (const c of r.decisions) assert(v.decisions.some(x => x.id === c.id && x.proposalHash === c.proposalHash) && choices.includes(c.status) && typeof c.note === 'string', 'Invalid decision review');
  } else {
    const ready = readiness(d);
    assert(JSON.stringify(r.runIds) === JSON.stringify(ready.runIds), 'Stale QA runs');
    assert(['approved', 'conditional-complete', 'revise', 'hold'].includes(r.verdict), 'Invalid verdict');
    assert(r.computedStatus === ready.status && typeof r.note === 'string', 'Wrong verification result');
    assert(Array.isArray(r.acceptedIssueIds) && new Set(r.acceptedIssueIds).size === r.acceptedIssueIds.length && r.acceptedIssueIds.every(id => ready.issues.some(i => i.id === id && i.severity === 'minor')), 'Invalid issue acceptance');
    if (r.verdict === 'approved') assert(ready.status === 'complete', 'Cannot approve incomplete verification');
    if (r.verdict === 'conditional-complete') assert(ready.status === 'conditional-complete' && ready.issues.every(i => r.acceptedIssueIds.includes(i.id)), 'Every minor issue needs explicit acceptance');
  }
  return r;
}
export function validateReview(d, review) {
  validateRound(d, review);
  assert(Array.isArray(review.history) && review.history.length === review.round, 'Missing round history');
  review.history.forEach((r, i) => { assert(r.round === i + 1, 'Non-sequential history'); validateRound(d, r); });
  const {history, ...latest} = review;
  assert(JSON.stringify(latest) === JSON.stringify(review.history.at(-1)), 'Review/history mismatch');
  return review;
}
