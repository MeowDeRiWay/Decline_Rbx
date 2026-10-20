"""Exercise authoritative inventory restoration, transfers, resets and one-time break notice."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/InventoryService.luau').read_text()
service=re.sub(r'local (ItemConfig|Rules|CombatRules|Visuals|Journal)\s*=\s*require[^\n]+\n','',service)
setup='''
local Journal=journalPlaceholder
local notices=ReplicatedStorage:FindFirstChild("PersonalNotice").sent
local Visuals={Apply=function() end,Validate=function() return true end}
local baseNew=Instance.new
function Instance.new(kind)
 local value=baseNew(kind)
 if kind=="BindableEvent" then value.Event=event();value.Fire=function(self,...) self.Event:Fire(...) end end
 return value
end
'''
setup=setup.replace('journalPlaceholder','(function()\n'+(root/'src/server/Services/JournalService.luau').read_text()+'\nend)()')
cases='''
a:LoadCharacterAsync();Service.Reset(a)
assert(Service.Add(a,"Rifle223",1,{17}))
assert(Service.Equip(a,"Rifle223"))
assert(Service.ToggleHolster(a) and Service.Snapshot(a).Equipment.Hands==nil)
assert(Service.Snapshot(a).Items.Rifle223==1)
assert(Service.ToggleHolster(a) and Service.Snapshot(a).Equipment.Hands=="Rifle223")
assert(a.Character:GetAttribute("WeaponCondition")==17,"condition preserved")
assert(Service.ToggleHolster(a));assert(Service.Remove(a,"Rifle223",1))
assert(Service.Add(a,"Rifle223",1,{99}))
assert(not Service.ToggleHolster(a),"dropping original invalidates memory, new same-ID weapon cannot restore it")
assert(Service.Equip(a,"Rifle223"));assert(Service.ToggleHolster(a))
local storage=Rules.New()
assert(Service.Transfer(a,storage,"Rifle223",1,true))
assert(not Service.ToggleHolster(a),"transfer invalidates holster memory")
assert(Service.Add(a,"Rifle223",1,{1}));assert(Service.Equip(a,"Rifle223"))
Service.UseWeapon(a);assert(#notices==1 and notices[1].data:find("broke",1,true))
Service.UseWeapon(a);assert(#notices==1,"broken item does not repeat notification")
assert(notices[1].player==a,"personal notices are sent only to their owner")
Service.Reset(a);assert(not Service.ToggleHolster(a),"reset clears memory")
print("PASS: holster toggle preserves condition, drop/replacement/transfer cannot restore missing weapon, reset and one break notice")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text()]
for name,module in [('ItemConfig','ItemConfig'),('Rules','InventoryRules'),('CombatRules','CombatRules')]:
 parts.append(f'local {name}=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
parts += [setup,'local Service=(function()\n'+service+'\nend)()',cases]
with tempfile.TemporaryDirectory() as folder:
 path=Path(folder)/'holster.luau';path.write_text('\n'.join(parts));subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
