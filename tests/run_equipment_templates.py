"""Test actual world-tool template capture/validation on mock Instances."""
from pathlib import Path
import subprocess
import tempfile
import sys
root=Path(__file__).resolve().parents[1]
service=(root/'src/server/Services/EquipmentVisuals.luau').read_text().replace('local Items = require(ReplicatedStorage.Shared.ItemConfig)','')
cases='''
local world=make("Folder","WorldItems",workspace)
for _,id in ipairs({"StoneAxe","StoneShowel","ScrapAxe","ScrapShowel","IronAxe","IronShowel","ScrapKnife","IronKnife"}) do
 local item=make("Model",id,world,{Quantity=1})
 make("Part","Part",item)
 Visuals.CaptureTemplate(item,id)
 assert(Visuals.Validate(id),"registered world tool must be equippable")
 local captured=ServerStorage.Items:FindFirstChild(id)
 assert(captured and captured~=item and captured:GetAttribute("Quantity")==nil)
 item:Destroy()
 assert(Visuals.Validate(id),"pickup removal must not remove held-item template")
 local another=make("Model",id,world); make("Part","Part",another)
 Visuals.CaptureTemplate(another,id)
 assert(ServerStorage.Items:FindFirstChild(id)==captured,"authored/existing template wins")
end
local stone=make("Model","Stone",world); make("Part","Part",stone)
Visuals.CaptureTemplate(stone,"Stone")
assert(not ServerStorage.Items:FindFirstChild("Stone"),"ordinary loot is not equipment")
print("PASS: all eight world equipment models supply templates, survive pickup removal and preserve existing templates")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),'local Items=(function()\n'+(root/'src/shared/ItemConfig.luau').read_text()+'\nend)()','local Visuals=(function()\n'+service+'\nend)()',cases]
with tempfile.TemporaryDirectory(prefix='decline-equipment-') as directory:
 p=Path(directory)/'test.luau';p.write_text('\n'.join(parts))
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
