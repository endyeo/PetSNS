import http from 'node:http';
import {createReadStream,statSync} from 'node:fs';
import {resolve,extname,sep} from 'node:path';
const [rootArg,portArg]=process.argv.slice(2), root=resolve(rootArg || '.');
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript','.mjs':'text/javascript','.css':'text/css','.json':'application/json','.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml','.wasm':'application/wasm','.woff2':'font/woff2'};
const server=http.createServer((req,res)=>{try{const relative=decodeURIComponent(new URL(req.url,'http://localhost').pathname).replace(/^\/+/,''),path=resolve(root,relative||'index.html');if(path!==root&&!path.startsWith(root+sep))throw new Error('invalid path');if(!statSync(path).isFile())throw new Error('not a file');res.setHeader('Content-Type',types[extname(path)]||'application/octet-stream');res.setHeader('Cache-Control','no-store');createReadStream(path).pipe(res);}catch{res.writeHead(404);res.end('Not found');}});
server.listen(Number(portArg||8765),'127.0.0.1',()=>console.log(`Serving ${root} at http://127.0.0.1:${server.address().port}`));
