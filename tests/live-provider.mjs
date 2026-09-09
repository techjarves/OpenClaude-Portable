// Opt-in live provider smoke test. Sends only a synthetic temporary project.
import { mkdtempSync, writeFileSync, readFileSync, existsSync, rmSync, realpathSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { readConfig, redact } from '../lib/config.mjs';
import { SessionStore } from '../lib/sessions.mjs';
import { AgentManager } from '../lib/agent.mjs';
const config=readConfig(),profile=config.profiles[config.active];
if(!profile)throw new Error('Configure a provider first');
const workspace=realpathSync(mkdtempSync(join(tmpdir(),'Portable AI live test ')));
writeFileSync(join(workspace,'input.txt'),'The verification word is ORBIT.\n');
const store=new SessionStore(join(workspace,'sessions'));const manager=new AgentManager(store);
const session=store.create({workspace,profile,trusted:true});let approved=0;
const timer=setTimeout(()=>{console.log('Live test time limit reached; cancelling.');manager.cancel(session.id);},180000);
try{
  console.log(`Live provider: ${profile.provider}; model: ${profile.model}; synthetic workspace only.`);
  const run=await manager.start(session.id,`This is a small smoke test. Use the Read tool to read ${join(workspace,'input.txt')}. Use the Write tool to create ${join(workspace,'output.txt')} containing exactly ORBIT followed by a newline. Use Bash with the command exactly node --version, with no prefix or suffix. Do not use subagents, inspect other directories, or perform any other task. Then report the word and Node version.`,{},event=>{
    if(event.type==='approval'){
      const safeWrite=event.tool==='Write'&&event.input.file_path===join(workspace,'output.txt');
      const safeCommand=event.tool==='Bash'&&event.input.command.trim()==='node --version';
      const safeRead=event.tool==='Read'&&event.input.file_path===join(workspace,'input.txt');
      const allow=safeWrite||safeCommand||safeRead;
      console.log(`Approval ${event.tool}: ${allow?'allowed for synthetic fixture':'denied (outside test scope)'}`);
      if(allow)approved++;setImmediate(()=>manager.approve(session.id,event.requestId,allow));
    }
    if(event.type==='tool')console.log('Tool:',event.name);
    if(event.type==='result')console.log('Result:',event.status,event.error?redact(event.error):'');
  });await run.promise;
  const s=store.get(session.id);const output=existsSync(join(workspace,'output.txt'))?readFileSync(join(workspace,'output.txt'),'utf8'):null;
  const summary={status:s.status,provider:profile.provider,model:profile.model,approved,read:s.events.some(e=>e.type==='tool'&&e.name==='Read'),write:output==='ORBIT\n',command:s.events.some(e=>e.type==='tool'&&e.name==='Bash'),sdkSession:!!s.sdkSessionId,error:s.error||null};
  console.log(JSON.stringify(summary,null,2));
  if(s.status!=='completed'||!summary.read||!summary.write||!summary.command)process.exitCode=1;
}finally{clearTimeout(timer);await manager.close();rmSync(workspace,{recursive:true,force:true});}
