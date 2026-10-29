local tick=RunService.PreSimulation.Fire
RunService.PreSimulation:Fire(1/30)
local hip=c:FindFirstChild("LeftHip",true)
assert(hip.Transform)
root.CFrame=CFrame.new(.01,0,0)*root.CFrame
RunService.PreSimulation:Fire(1/30)
assert(math.abs(hip.Transform.R[3])+math.abs(hip.Transform.R[6])+math.abs(hip.Transform.R[2])>0,"actual movement poses hips")
local held=Instance.new("Part",c);held.Name="HeldItem";held.CFrame=root.CFrame*CFrame.new(.3,.2,-.3)
c:SetAttribute("HandsItem","Gun")
c.DescendantAdded:Fire(held);flush();RunService.PreSimulation:Fire(1/30)
local shoulder=c:FindFirstChild("RightShoulder",true)
assert(shoulder.Transform and shoulder.Transform.R[1]==shoulder.Transform.R[1],"late firearm poses arms without NaN")
local before=shoulder.Transform
c:SetAttribute("Knockout",true);RunService.PreSimulation:Fire(1/30)
assert(shoulder.Transform==before,"knockout pose left untouched")
c:SetAttribute("Knockout",false)
local remoteHip=oc:FindFirstChild("LeftHip",true)
assert(remoteHip.Transform,"other player is animated on this viewer")
otherRoot.CFrame=CFrame.new(300,0,0)*otherRoot.CFrame
local previous=remoteHip.Transform
RunService.PreSimulation:Fire(1/30);assert(remoteHip.Transform==previous,"distant rigs do no pose work")
local removed=c:FindFirstChild("LeftKnee",true)
c.DescendantRemoving:Fire(removed);removed.Parent=nil;flush()
RunService.PreSimulation:Fire(1/30)
removed.Parent=c:FindFirstChild("LeftUpperLeg");c.DescendantAdded:Fire(removed);flush()
RunService.PreSimulation:Fire(1/30)
Players.PlayerRemoving:Fire(other);owner.CharacterRemoving:Fire()
RunService.PreSimulation:Fire(1/30)
print("PASS: viewer controller movement, late weapon, other players, distance cull, knockout, partial streaming and cleanup")

-- Reuse precisely the client pose implementation in Studio's server viewport.
Driver.Start(nil,true)
for _,id in ipairs({"Pistol","Knife","Axe","Shovel"}) do
 c:SetAttribute("HandsItem",id);RunService.PreSimulation:Fire(1/30)
 assert(shoulder.Transform.R[1]==shoulder.Transform.R[1],"all equipment poses stay finite")
end
local lastRemote=remoteHip.Transform
RunService.PreSimulation:Fire(1/30)
assert(remoteHip.Transform~=lastRemote,"Studio preview poses players without a local viewer or distance cull")
print("PASS: pistol, knife, two-handed axe/shovel and shared Studio server preview")
