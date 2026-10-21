local Stats={}
function Stats.Calculate(attributes,definition,condition,health,maxHealth)
 local a=attributes
 local gun=definition and definition.Firearm
 local weapon=definition and definition.Weapon
 local category=gun and (gun.Category or "Rifle") or ""
 local melee=weapon and not gun
 local damage=melee and weapon.Damage or 0
 damage+=a.MeleeBonus or 0
 if melee and (condition or 0)<=0 then damage=0 end
 return {
  Health=health or 0,MaxHealth=maxHealth or a.MaxHealth or 100,
  Absorption=math.max(0,(a.ArmorAbsorption or 0)+(a.DamageAbsorption or 0)),
  MeleeAbsorption=math.max(0,(a.ArmorAbsorption or 0)+(a.DamageAbsorption or 0)+(a.MeleeAbsorption or 0)),
  Resistance=math.clamp((a.ArmorResistance or 0)+(a.DamageResistance or 0),0,1),
  Carry=a.CarryLimitKg or 20,WalkSpeed=1+(a.WalkBonus or 0),RunSpeed=3+(a.WalkBonus or 0)+(a.RunBonus or 0),Regeneration=a.Regeneration or 0,Sprint=20,Accuracy=math.clamp((a.Accuracy or 25)+(a[category.."AccuracyBonus"] or 0)+(gun and (a.WeaponAccuracyBonus or 0) or 0),0,300),
  Dodge=a.DodgeChance or 0,MeleeDamage=damage,MeleeEquipped=melee~=nil and melee~=false,
  CriticalChance=a.CriticalChance or 0,
  CriticalMin=2,CriticalMax=4,Luck=a.LuckChance or 0,
 }
end
return Stats
