const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const s=fs.readFileSync(path.join(__dirname,'../Dock.qml'),'utf8');
const begin=s.indexOf('  function focusWindow('),end=s.indexOf('  // Left click:',begin);
for(const usingLua of [true,false]) {
 const top={activate(){throw Error('generic activation must not be used')}},calls=[];
 const ctx={Hyprland:{usingLua,toplevels:{values:[{address:'abc123',wayland:top,workspace:{id:1}}]},dispatch:x=>calls.push(x)}};
 vm.createContext(ctx);vm.runInContext(s.slice(begin,end),ctx);ctx.focusWindow(top);
 assert.deepEqual(calls,[usingLua?'hl.dsp.focus({window="address:0xabc123"})':'focuswindow address:0xabc123']);
 ctx.focusWindow({});assert.equal(calls.length,1);
 ctx.Hyprland.toplevels.values[0].address='invalid"';ctx.focusWindow(top);assert.equal(calls.length,1);
}
console.log('PASS addressed focus for Lua/legacy, no migration or generic activation, stale handle ignored');
