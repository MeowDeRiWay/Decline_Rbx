local R={}
-- Temporarily disabled. Restore to 1 for Strength infection per landed hit.
R.InfectionPerStrength=0
function R.Infection(strength) return math.max(0,strength or 0)*R.InfectionPerStrength end
function R.Roll(random)
 return {Strength=random:NextInteger(3,6),Attention=random:NextInteger(3,6),Endurance=random:NextInteger(3,5),Intelligence=1,Agility=random:NextInteger(1,3),Luck=5}
end
return R
