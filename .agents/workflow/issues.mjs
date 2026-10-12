import {readFileSync,writeFileSync,mkdirSync,renameSync,openSync,closeSync,unlinkSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {assert,validateReview,readiness} from './model.mjs';
import {seal,digest} from './render.mjs';

export function prepare(report, review) {
  const d=seal(report);validateReview(d,review);
  assert(d.kind==='verification' && review.verdict==='conditional-complete', 'Only reviewed conditional completion can register issues');
  const ready=readiness(d);
  const entries=ready.issues.filter(i=>review.acceptedIssueIds.includes(i.id)).map(i=>{
    const key=digest([d.repository.toLowerCase(),d.taskId,i.id,i.location]);
    const marker=`<!-- petsns-issue:${key} -->`;
    return {key,marker,issueId:i.id,title:`[${d.taskId}] ${i.title}`,body:[marker,'',`경미한 잔여 문제: ${i.title}`,`위치: ${i.location}`,'',`관찰: ${i.actual}`,`기대: ${i.expected}`,'','재현:',...i.steps.map((s,n)=>`${n+1}. ${s}`),'',`작업: ${d.taskId} · 리비전: ${d.revision}`,`검증 실행: ${ready.runIds.join(', ')}`,`승인 회차: ${review.round} · 검토 시각: ${review.reviewedAt}`,`보고서 SHA-256: ${d.reportHash}`].join('\n')};
  });
  return {schemaVersion:1,repository:d.repository,taskId:d.taskId,revision:d.revision,reportHash:d.reportHash,reviewRound:review.round,entries};
}
export function record(ledger,queue,key,url,disposition) {
  assert(queue.schemaVersion===1 && queue.entries.some(i=>i.key===key),'Unknown issue key');
  assert(['created','reused'].includes(disposition),'Invalid disposition');
  assert(new RegExp(`^https://github\\.com/${queue.repository.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')}/issues/\\d+$`).test(url),'Wrong repository issue URL');
  assert(!ledger.repository || ledger.repository===queue.repository,'Wrong ledger repository');
  const previous=ledger.entries?.[key];assert(!previous || previous.url===url,'Conflicting existing issue URL');
  return {schemaVersion:1,repository:queue.repository,entries:{...ledger.entries,[key]:previous||{url,disposition,recordedAt:new Date().toISOString(),taskId:queue.taskId,issueId:queue.entries.find(i=>i.key===key).issueId}}};
}
export function reconcile(queue,inventory,ledger={}) {
  assert(inventory.repository===queue.repository && inventory.complete===true && Array.isArray(inventory.issues),'Complete open/closed issue inventory required');
  assert(!ledger.repository || ledger.repository===queue.repository,'Wrong ledger repository');
  const decisions=queue.entries.map(entry=>{
    const prior=ledger.entries?.[entry.key];
    const matches=inventory.issues.filter(i=>typeof i.body==='string' && i.body.includes(entry.marker));
    assert(matches.length<=1,'Multiple remote issues have the same marker; reconcile manually');
    if(matches.length){assert(!prior || prior.url===matches[0].url,'Ledger conflicts with GitHub');return {key:entry.key,action:'reuse',url:matches[0].url,state:matches[0].state};}
    if(prior){assert(inventory.issues.some(i=>i.url===prior.url),'Recorded issue missing from inventory; reconcile manually');return {key:entry.key,action:'reuse',url:prior.url};}
    const normalize=s=>String(s).normalize('NFKC').toLowerCase().replace(/\s+/g,' ').trim();
    const candidates=inventory.issues.filter(i=>normalize(i.title)===normalize(entry.title));
    return {key:entry.key,action:candidates.length?'review-candidates':'create',candidates:candidates.map(i=>({url:i.url,state:i.state,title:i.title}))};
  });
  return {schemaVersion:1,repository:queue.repository,decisions};
}
function read(path){return JSON.parse(readFileSync(path,'utf8'));}
function atomicWrite(path,data){mkdirSync(dirname(resolve(path)),{recursive:true});const temp=`${path}.${process.pid}.tmp`;writeFileSync(temp,JSON.stringify(data,null,2));renameSync(temp,path);}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  try {
    const [command,...args]=process.argv.slice(2);
    if(command==='prepare') {assert(args.length===3,'prepare REPORT REVIEW QUEUE');atomicWrite(args[2],prepare(read(args[0]),read(args[1])));console.log('Issue queue prepared. No GitHub writes performed.');}
    else if(command==='reconcile') {assert(args.length===4,'reconcile QUEUE INVENTORY LEDGER OUTPUT');let ledger={};try{ledger=read(args[2]);}catch(e){if(e.code!=='ENOENT')throw e;}atomicWrite(args[3],reconcile(read(args[0]),read(args[1]),ledger));console.log('Duplicate check prepared. No GitHub writes performed.');}
    else if(command==='record') {
      assert(args.length===5,'record LEDGER QUEUE KEY URL created|reused');
      const [path,q,key,url,disposition]=args, lock=`${path}.lock`;
      let fd;try {fd=openSync(lock,'wx');let ledger={};try{ledger=read(path);}catch(e){if(e.code!=='ENOENT')throw e;}atomicWrite(path,record(ledger,read(q),key,url,disposition));}finally{if(fd!==undefined){closeSync(fd);unlinkSync(lock);}}
      console.log('Issue registration recorded.');
    } else throw new Error('Usage: issues.mjs prepare|reconcile|record');
  }catch(e){console.error(e.message);process.exitCode=1;}
}
