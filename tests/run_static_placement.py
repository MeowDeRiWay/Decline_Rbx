"""Exercise real static placement against all603 parts /369 models from Factory.rbxm."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
geometry=(root/'tests/city_geometry.fixture.luau').read_text()
service=(root/'src/server/Services/StaticPlacement.luau').read_text()
fixture=(root/'tests/fixtures/factory_placement.luau').read_text()
cases='''
local function build()
 local nodes={}
 for _,entry in ipairs(Data.Nodes) do
  local object={Kind=entry.Kind,Name=entry.Name,Anchored=entry.Anchored,Children={}}
  function object:IsA(kind) return self.Kind==kind or (kind=="BasePart" and self.Kind=="Part") end
  function object:GetPivot() return self.PrimaryPart and self.PrimaryPart.CFrame or self.WorldPivot end
  function object:GetDescendants()
   local result={}
   local function visit(o) for _,child in ipairs(o.Children) do table.insert(result,child);visit(child) end end
   visit(self);return result
  end
  if entry.Position then object.CFrame=cf(entry.Position,entry.Yaw) else object.WorldPivot=CFrame.new() end
  nodes[entry.ID]=object
 end
 for _,entry in ipairs(Data.Nodes) do
  local o=nodes[entry.ID]
  if entry.Parent>=0 then o.Parent=nodes[entry.Parent];table.insert(o.Parent.Children,o) end
  if entry.Primary then o.PrimaryPart=nodes[entry.Primary] end
 end
 return nodes
end
for _,yaw in ipairs({0,math.pi/2,math.pi,-math.pi/2}) do
 local nodes=build();local factory=nodes[0];local yard=nodes[963]
 assert(factory.PrimaryPart==yard.PrimaryPart and factory.PrimaryPart==nodes[964])
 local origin=factory:GetPivot();local target=cf(Data.Plot,yaw)
 local before={};local partCount,sharedCount=0,0
 local seen={}
 for id,o in pairs(nodes) do
  if o:IsA("BasePart") then before[id]=o.CFrame;partCount+=1 end
  if o.PrimaryPart then if seen[o.PrimaryPart] then sharedCount+=1 end;seen[o.PrimaryPart]=true end
 end
 assert(partCount==603 and sharedCount==183)
 Placement.Move(factory,target)
 assert((factory:GetPivot().Position-Data.Plot).Magnitude<1e-6 and (yard:GetPivot().Position-Data.Plot).Magnitude<1e-6)
 for id,old in pairs(before) do
  local expected=target*origin:ToObjectSpace(old)
  assert((nodes[id].CFrame.Position-expected.Position).Magnitude<1e-6 and nodes[id].Anchored,"every physical part moves exactly once and remains anchored")
 end
 -- Moving the same hierarchy again must remain a rigid transform, without cumulative drift.
 Placement.Move(factory,cf(Data.Plot+Vector3.new(5,2,8),yaw))
 assert((yard:GetPivot().Position-(Data.Plot+Vector3.new(5,2,8))).Magnitude<1e-6)
end
local model={WorldPivot=CFrame.new(Vector3.new(10,3,20)),IsA=function(_,k) return k=="Model" end}
local part={CFrame=CFrame.new(Vector3.new(11,4,22)),IsA=function(_,k) return k=="BasePart" end}
function model:GetPivot() return self.WorldPivot end
function model:GetDescendants() return {part} end
Placement.Move(model,CFrame.new())
assert(part.CFrame.Position.X==1 and part.CFrame.Position.Y==1 and part.CFrame.Position.Z==2 and model.WorldPivot.Position.Magnitude==0)
print("PASS: actual603 factory parts,183 shared PrimaryParts, matching Yard/plot at all4yaws, repeated rigid movement, anchor flags and no-PrimaryPart pivot")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'placement.luau';p.write_text(geometry+'\nlocal Placement=(function()\n'+service+'\nend)()\nlocal Data=(function()\n'+fixture+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1],str(p)],check=True)
