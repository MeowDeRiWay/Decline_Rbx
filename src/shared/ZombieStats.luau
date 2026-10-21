local R={}
function R.Roll(random)
 return {Strength=random:NextInteger(3,6),Attention=random:NextInteger(3,6),Endurance=random:NextInteger(3,5),Intelligence=1,Agility=random:NextInteger(1,3),Luck=5}
end
return R
