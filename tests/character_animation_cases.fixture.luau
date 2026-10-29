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
c:SetAttribute("HandsItem","Knife");RunService.PreSimulation:Fire(1/30)
local guard=c:FindFirstChild("LeftShoulder",true)
local guardElbow=c:FindFirstChild("LeftElbow",true)
local s=guard:GetAttribute("StandingRotation")*guard.Transform
local endpoint=s:VectorToWorldSpace(guard:GetAttribute("UpperVector"))+(s*guardElbow.Transform):VectorToWorldSpace(guard:GetAttribute("LowerVector"))
local anchor=(guard.Part0.CFrame*guard:GetAttribute("AuthoredC0")*CFrame.new(guard:GetAttribute("StandingOffset"))).Position
local hand=root.CFrame:PointToObjectSpace(anchor+root.CFrame:VectorToWorldSpace(endpoint))
assert(hand.Z<-.4 and hand.Y>.1,"knife free hand is raised in front of the body")
c:SetAttribute("HandsItem","Shovel");RunService.PreSimulation:Fire(1/30)
local lastRemote=remoteHip.Transform
RunService.PreSimulation:Fire(1/30)
assert(remoteHip.Transform~=lastRemote,"Studio preview poses players without a local viewer or distance cull")
print("PASS: pistol, knife, two-handed axe/shovel and shared Studio server preview")
local oldHeld=c:FindFirstChild("HeldItem");if oldHeld then oldHeld.Parent=nil end
c:SetAttribute("HandsItem",nil)
local function wrist(side)
 local shoulder=c:FindFirstChild(side.."Shoulder",true)
 local elbow=c:FindFirstChild(side.."Elbow",true)
 local rotation=shoulder:GetAttribute("StandingRotation")*shoulder.Transform
 local delta=rotation:VectorToWorldSpace(shoulder:GetAttribute("UpperVector"))+(rotation*elbow.Transform):VectorToWorldSpace(shoulder:GetAttribute("LowerVector"))
 local anchor=(shoulder.Part0.CFrame*shoulder:GetAttribute("AuthoredC0")*CFrame.new(shoulder:GetAttribute("StandingOffset"))).Position
 return root.CFrame:PointToObjectSpace(anchor+root.CFrame:VectorToWorldSpace(delta))
end
Punch.Begin(c,serverTime);serverTime+=Punch.Contact;RunService.PreSimulation:Fire(1/30)
assert(wrist("Right").Z<-.7 and wrist("Left").Z>-.4 and wrist("Left").Y>.1,"right punch reaches contact while left hand guards")
serverTime+=1-Punch.Contact;Punch.Begin(c,serverTime);serverTime+=Punch.Contact;RunService.PreSimulation:Fire(1/30)
assert(wrist("Left").Z<-.7 and wrist("Right").Z>-.4,"next accepted punch uses the left hand")
serverTime+=2;RunService.PreSimulation:Fire(1/30)
assert(wrist("Left").Y<-.3 and wrist("Right").Y<-.3,"both arms return to idle after combat")
print("PASS: alternating unarmed punches, opposite-hand guard, synchronized contact and idle recovery")
