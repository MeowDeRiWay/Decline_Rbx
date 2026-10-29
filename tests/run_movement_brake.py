from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
mock='''
local cb
local c={attrs={}}
local root={AssemblyLinearVelocity={X=.4,Y=-2,Z=.3}}
local hp={Health=100,FloorMaterial="Grass",MoveDirection={Magnitude=0}}
function c:FindFirstChild() return root end
function c:FindFirstChildOfClass() return hp end
function c:GetAttribute(k) return self.attrs[k] end
local Players={LocalPlayer={Character=c}}
game={GetService=function(_,name) if name=="Players" then return Players else return {PreSimulation={Connect=function(_,fn) cb=fn end}} end end}
Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end}
Enum={Material={Air="Air"}}
'''
cases='''
cb();assert(root.AssemblyLinearVelocity.X==0 and root.AssemblyLinearVelocity.Z==0 and root.AssemblyLinearVelocity.Y==-2)
for _,scenario in ipairs({"air","moving","knockout","anchored","platform","dead"}) do
 root.AssemblyLinearVelocity={X=1,Y=2,Z=3}
 hp.FloorMaterial=scenario=="air" and "Air" or "Grass"
 hp.MoveDirection.Magnitude=scenario=="moving" and 1 or 0
 hp.Health=scenario=="dead" and 0 or 100
 c.attrs.Knockout=scenario=="knockout"
 root.Anchored=scenario=="anchored";hp.PlatformStand=scenario=="platform"
 cb();assert(root.AssemblyLinearVelocity.X==1,scenario)
end
print("PASS: grounded stop preserves vertical velocity and ignores movement, air, anchored, KO, dead and forced physics")
'''
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'brake.luau';p.write_text(mock+(root/'src/client/MovementBrake.client.luau').read_text()+cases)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
