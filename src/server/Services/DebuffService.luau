local Shared=game:GetService("ReplicatedStorage").Shared
local Config=require(Shared.MedicalConfig)
local Rules=require(Shared.MedicalRules)
local Service={}
function Service.Poison(character)
 if not character or character:GetAttribute("IsDead") then return false end
 character:SetAttribute("Poisoned",true);return true
end
function Service.ZombieHit(character,random)
 if Config.ZombiePoisonEnabled and random:NextNumber()<Config.PoisonChance then return Service.Poison(character) end
 return false
end
function Service.Step(character,dt)
 if character:GetAttribute("HospitalResting") or character:GetAttribute("Knockout") then return end
 if character:GetAttribute("Poisoned") then character:SetAttribute("Sick",math.min(100,(character:GetAttribute("Sick") or 0)+Config.PoisonSickPerSecond*dt)) end
end
function Service.Treat(character,dt)
 local sick=math.max(0,(character:GetAttribute("Sick") or 0)-Config.HospitalSickPerSecond*dt)
 character:SetAttribute("Sick",sick)
 if sick==0 then character:SetAttribute("Poisoned",false) end
 return sick==0 and not character:GetAttribute("Poisoned")
end
return Service
