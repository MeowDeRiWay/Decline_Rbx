local Players=game:GetService("Players")
local Locale=require(script.Parent.LocaleController)
local localPlayer=Players.LocalPlayer
local Examination={}
function Examination.Text(patient)
 if not localPlayer:GetAttribute("QuickExamination") or patient==localPlayer then return nil end
 local c=patient and patient.Character
 local own=localPlayer.Character
 local root=own and own:FindFirstChild("HumanoidRootPart")
 local body=c and c:FindFirstChild("HumanoidRootPart")
 local hp=c and c:FindFirstChildOfClass("Humanoid")
 if not root or not body or not hp or not c:GetAttribute("Knockout") or c:GetAttribute("IsDead") or (body.Position-root.Position).Magnitude>3 then return nil end
 local lines={
  Locale.Text(string.format("Patient: HP %g / %g",math.floor(hp.Health*10)/10,hp.MaxHealth)),
  Locale.Text(string.format("Sickness: %g%%",math.floor((c:GetAttribute("Sick") or 0)*10)/10)),
  Locale.Text(c:GetAttribute("Poisoned") and "Poisoning: present" or "Poisoning: absent"),
 }
 if (c:GetAttribute("Food") or 100)<=0 then table.insert(lines,Locale.Text("Starvation")) end
 if (c:GetAttribute("Water") or 100)<=0 then table.insert(lines,Locale.Text("Dehydration")) end
 return table.concat(lines,"\n")
end
return Examination
