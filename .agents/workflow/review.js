const report = JSON.parse(document.getElementById('report-data').textContent);
const key = `petsns.workflow.v1:${report.repository}:${report.taskId}:${report.kind}:${report.reportHash}`;
let state = {drafts: {}, history: []}, storageError = false;
const root = document.getElementById('content'), message = document.getElementById('message');
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const msg = text => { message.textContent = text; };
const latestVersion = report.versions?.at(-1);
let selected = latestVersion?.id, active = report.kind === 'plan' ? 'plan' : 'developer';
function persist() {
  try { localStorage.setItem(key, JSON.stringify(state)); storageError = false; return true; }
  catch { storageError = true; msg('브라우저 저장 실패. 선택을 보존할 수 없습니다. 저장 공간·권한을 복구한 뒤 다시 저장하세요.'); return false; }
}
try {
  const saved = JSON.parse(localStorage.getItem(key) || 'null');
  if (saved) {
    if (saved.history?.length) validateReview(report, {...saved.history.at(-1), history: saved.history});
    assert(saved.drafts && typeof saved.drafts === 'object', 'Invalid drafts');
    state = saved;
  }
} catch { storageError = true; msg('저장된 데이터가 유효하지 않거나 접근이 차단되었습니다. 확인된 JSON을 가져오거나 저장을 다시 시도하세요.'); }
document.getElementById('title').textContent = report.title;
document.getElementById('identity').textContent = `${report.taskId} · ${report.repository} · ${report.revision.slice(0, 12)} · ${report.kind === 'plan' ? '계획 검토' : '실제 검증'}`;
const tabs = report.kind === 'plan' ? [['plan','계획·결정'],['compare','시안 비교'],['sources','PRD·코드 근거'],['history','승인 이력']] : [['developer','개발자 검증'],['qa','독립 QA'],['screens','실제 화면'],['review','결과 검토'],['history','QA·승인 이력'],['sources','PRD·코드 근거']];
document.getElementById('tabs').innerHTML = tabs.map(([id,title]) => `<button role="tab" id="tab-${id}" data-tab="${id}">${title}</button>`).join('');
document.getElementById('tabs').addEventListener('click', event => { if (event.target.dataset.tab) { active = event.target.dataset.tab; draw(); } });
function draft(v) {
  if (!state.drafts[v.id]) state.drafts[v.id] = Object.fromEntries(v.decisions.map(d => [d.id,{status:'hold',note:''}]));
  return state.drafts[v.id];
}
function figures(mockups, label) {
  return mockups.map(m => `<figure><img loading="lazy" src="${esc(m.path)}" alt="${esc(m.title)}"><figcaption>${esc(label)} · ${esc(m.title)}</figcaption></figure>`).join('') || '<p class="muted">이미지 시안 없음. 아래 결정 비교를 확인하세요.</p>';
}
function versionBody(v, editable) {
  const entries = draft(v);
  return `<p>${esc(v.summary)}</p>${figures(v.mockups, '계획 시안, 실제 앱 캡처 아님')}<h2>핵심 결정</h2>` + v.decisions.map(d => `<article class="card"><h3>${esc(d.id)} · ${esc(d.title)}</h3>${d.requiresExplicitApproval ? '<span class="tag">명시적 승인 필요</span>' : ''}<p>${esc(d.proposal)}</p><p><b>이유</b> ${esc(d.reason)}</p><p><b>영향</b> ${esc(d.impact)}</p>${editable ? `<label>결정 상태 <select data-decision="${esc(d.id)}">${[['approved','승인'],['revise','수정'],['hold','보류']].map(([id,label])=>`<option value="${id}" ${entries[d.id]?.status===id?'selected':''}>${label}</option>`).join('')}</select></label><label>수정 내용·메모<textarea data-note="${esc(d.id)}">${esc(entries[d.id]?.note || '')}</textarea></label>` : ''}</article>`).join('') + `<h2>완료 기준</h2><ul>${v.acceptance.map(x=>`<li>${esc(x)}</li>`).join('')}</ul>`;
}
function options(value) { return report.versions.map(v=>`<option value="${esc(v.id)}" ${v.id===value?'selected':''}>${esc(v.id)} · ${esc(v.summary)}</option>`).join(''); }
function runBody(r) {
  return `<article class="card"><h2>${esc(r.id)} · ${r.role === 'independent-qa' ? '독립 QA' : '개발자 검증'}</h2><p>${esc(r.actor)} · ${esc(r.executedAt)}<br>${esc(r.environment.url)} · ${esc(r.environment.viewport)}<br>빌드 ${esc(r.environment.build)} · ${esc(r.revision)}</p>${r.checks.map(c=>`<article class="card"><h3 class="${c.result}">${esc(c.title)} · ${{passed:'통과',failed:'실패','not-run':'미실행'}[c.result]}</h3><p>${esc(c.observed)}</p>${c.evidence.map(e=>e.kind==='screenshot'?figures([{title:`${c.title} · ${e.capturedAt}`,path:e.path}],'실제 화면 증거'): `<pre>${esc(e.command || e.path)}</pre>`).join('')}${c.issueIds.length?`<p>연결 문제: ${c.issueIds.map(esc).join(', ')}</p>`:''}</article>`).join('')}${r.issues.map(i=>`<p class="${i.severity==='minor'?'muted':'blocked'}">${esc(i.id)} · ${esc(i.severity)} · ${esc(i.title)}<br>관찰: ${esc(i.actual)}<br>기대: ${esc(i.expected)}</p>`).join('')}</article>`;
}
function draw() {
  tabs.forEach(([id])=>document.getElementById(`tab-${id}`).setAttribute('aria-selected', String(id===active)));
  if (active === 'plan') {
    const v = report.versions.find(v=>v.id===selected);
    root.innerHTML = `<div class="toolbar"><label>시안 회차 <select id="version">${options(selected)}</select></label><span class="tag">${v===latestVersion?'현재 시안':'과거 시안, 현재 구현 승인에 사용하지 않음'}</span></div>${versionBody(v,true)}`;
    document.getElementById('version').onchange = e => { selected=e.target.value; draw(); };
    root.querySelectorAll('[data-decision]').forEach(el=>el.onchange=()=>{draft(v)[el.dataset.decision].status=el.value;persist();});
    root.querySelectorAll('[data-note]').forEach(el=>el.oninput=()=>{draft(v)[el.dataset.note].note=el.value;persist();});
  } else if (active === 'compare') {
    root.innerHTML = `<div class="compare">${[0,1].map((_,i)=>`<section><label>${i?'새 시안':'이전 시안'} <select id="compare-${i}">${options(i?latestVersion.id:report.versions[0].id)}</select></label><div id="version-${i}"></div></section>`).join('')}</div>`;
    const update = i => { const v=report.versions.find(v=>v.id===document.getElementById(`compare-${i}`).value); document.getElementById(`version-${i}`).innerHTML=versionBody(v,false); };
    for (let i=0;i<2;i++){update(i);document.getElementById(`compare-${i}`).onchange=()=>update(i);}
  } else if (active === 'sources') {
    root.innerHTML='<h2>실제 읽은 PRD·코드</h2>'+report.sources.map(s=>`<article class="card"><h3>${esc(s.path)}</h3><small>SHA-256 ${esc(s.sha256)}</small><pre>${esc(s.excerpt)}</pre></article>`).join('');
  } else if (['developer','qa'].includes(active)) {
    const role=active==='qa'?'independent-qa':'developer', r=currentRuns(report).find(r=>r.role===role);
    root.innerHTML=r?runBody(r):'<article class="card blocked">현재 리비전의 실행 기록이 없습니다. 미검증입니다.</article>';
  } else if (active === 'screens') {
    root.innerHTML='<h2>실제 웹 화면</h2>'+currentRuns(report).map(r=>`<h3>${esc(r.id)} · ${esc(r.actor)}</h3>`+r.checks.flatMap(c=>c.evidence.filter(e=>e.kind==='screenshot').map(e=>({title:`${c.title} · ${e.capturedAt}`,path:e.path}))).map(m=>figures([m],'실행 캡처')).join('')).join('');
  } else if (active === 'review') {
    const ready=readiness(report), review=state.drafts.verification||{verdict:'hold',note:'',acceptedIssueIds:[]};
    state.drafts.verification=review;
    root.innerHTML=`<article class="card"><h2 class="${ready.status==='blocked'?'blocked':'passed'}">검증 결과: ${{blocked:'완료 차단',complete:'완료 가능','conditional-complete':'조건부 완료 가능'}[ready.status]}</h2>${ready.reasons.map(x=>`<p>${esc(x)}</p>`).join('')}<label>최종 결정 <select id="verdict">${[['approved','승인'],['conditional-complete','조건부 완료'],['revise','수정'],['hold','보류']].map(([id,label])=>`<option value="${id}" ${review.verdict===id?'selected':''} ${((id==='approved'&&ready.status!=='complete')||(id==='conditional-complete'&&ready.status!=='conditional-complete'))?'disabled':''}>${label}</option>`).join('')}</select></label><label>메모<textarea id="review-note">${esc(review.note)}</textarea></label>${ready.issues.map(i=>`<label><input data-issue="${esc(i.id)}" type="checkbox" ${review.acceptedIssueIds.includes(i.id)?'checked':''} ${i.severity!=='minor'?'disabled':''}> 경미한 문제 수용: ${esc(i.title)} (${esc(i.id)}, ${esc(i.severity)})</label>`).join('')}</article>`;
    document.getElementById('verdict').onchange=e=>{review.verdict=e.target.value;persist();};
    document.getElementById('review-note').oninput=e=>{review.note=e.target.value;persist();};
    root.querySelectorAll('[data-issue]').forEach(el=>el.onchange=()=>{review.acceptedIssueIds=[...root.querySelectorAll('[data-issue]:checked')].map(x=>x.dataset.issue);persist();});
  } else if (active === 'history') {
    root.innerHTML='<h2>승인 회차 이력</h2>'+(!state.history.length?'<p>저장된 승인 회차 없음</p>':state.history.map(r=>`<article class="card"><h3>회차 ${r.round} · ${esc(r.reviewedAt)}</h3><p>${esc(r.versionId || r.verdict)}</p><pre>${esc(JSON.stringify(r.decisions || {verdict:r.verdict,acceptedIssueIds:r.acceptedIssueIds},null,2))}</pre><button data-download="${r.round}">이 회차 JSON 다운로드</button></article>`).join(''));
    if(report.kind==='verification') root.innerHTML+='<h2>모든 QA·개발자 실행 이력</h2>'+report.runs.map(runBody).join('');
    root.querySelectorAll('[data-download]').forEach(el=>el.onclick=()=>downloadRound(Number(el.dataset.download)));
  }
}
function envelope() {
  const common={schemaVersion:1,kind:`${report.kind}-review`,project:report.project,taskId:report.taskId,repository:report.repository,revision:report.revision,reportHash:report.reportHash,round:state.history.length+1,reviewedAt:new Date().toISOString()};
  if(report.kind==='plan') {
    const v=report.versions.find(v=>v.id===selected);
    return {...common,versionId:v.id,versionHash:v.versionHash,decisions:v.decisions.map(c=>({id:c.id,proposalHash:c.proposalHash,...draft(v)[c.id]}))};
  }
  const ready=readiness(report), r=state.drafts.verification||{verdict:'hold',note:'',acceptedIssueIds:[]};
  return {...common,runIds:ready.runIds,computedStatus:ready.status,...r};
}
function downloadRound(round) {
  if(storageError && !persist()) return;
  const entry=state.history[round-1], data={...entry,history:state.history.slice(0,round)};
  validateReview(report,data);
  const url=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)],{type:'application/json'})), a=document.createElement('a');
  a.href=url;a.download=`${report.taskId}-${report.kind}-round-${round}.json`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  msg(`회차 ${round} JSON을 다운로드했습니다.`);
}
document.getElementById('save').onclick=()=>{
  try {
    const entry=envelope();validateRound(report,entry);
    const previous=state.history; state.history=[...previous,entry];
    if(!persist()){state.history=previous;return;}
    downloadRound(entry.round);if(active==='history')draw();
  } catch(e){msg(`저장 불가: ${e.message}`);}
};
document.getElementById('import').onchange=async event=>{
  const file=event.target.files[0];if(!file)return;
  try {
    const data=JSON.parse(await file.text());validateReview(report,data);
    assert(data.round>=state.history.length,'이전 JSON으로 현재 이력을 덮어쓸 수 없습니다.');
    state.history.forEach((r,i)=>assert(JSON.stringify(r)===JSON.stringify(data.history[i]),'기존 승인 이력과 충돌합니다.'));
    const next={drafts:structuredClone(state.drafts),history:data.history};
    for(const r of data.history) {
      if(report.kind==='plan')next.drafts[r.versionId]=Object.fromEntries(r.decisions.map(c=>[c.id,{status:c.status,note:c.note}]));
      else next.drafts.verification={verdict:r.verdict,note:r.note,acceptedIssueIds:r.acceptedIssueIds};
    }
    const previous=state;state=next;
    if(!persist()){state=previous;return;}
    if(report.kind==='plan')selected=data.versionId;
    draw();msg(`회차 ${data.round}까지 가져왔습니다.`);
  }catch(e){msg(`가져오기 거부: ${e.message}`);}
  event.target.value='';
};
draw();
