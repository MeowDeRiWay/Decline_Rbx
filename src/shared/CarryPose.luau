-- One-shoulder carry: patient's belly rests on the carrier's left shoulder,
-- head/arms hang in front and legs hang behind. Gameplay still treats them as KO.
local Carry={}
function Carry.Frame(carrier,patientRoot,root)
 local torso=carrier:FindFirstChild("UpperTorso") or root
 local x=-torso.Size.X/2-patientRoot.Size.X*.35
 local y=torso.Size.Y/2+patientRoot.Size.Z/2+.025
 return torso.CFrame*CFrame.new(x,y,.02)*CFrame.Angles(-math.pi/2,0,0)
end
function Carry.SupportPoint(carrier,root)
 local torso=carrier:FindFirstChild("UpperTorso") or root
 return torso.CFrame:PointToWorldSpace(Vector3.new(-torso.Size.X/2-root.Size.X*.35,torso.Size.Y*.35,.25))
end
return Carry
