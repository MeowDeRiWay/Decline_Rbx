local Rules={}
function Rules.SameFaction(a,b)
 if not a or not b then return false end
 local team=a:GetAttribute("TeamID")
 return typeof(team)=="number" and team>0 and team==b:GetAttribute("TeamID")
end
function Rules.Friendly(a,b)
 if not a or not b then return false end
 local group=a:GetAttribute("GroupID")
 return Rules.SameFaction(a,b) or (typeof(group)=="number" and group>0 and group==b:GetAttribute("GroupID"))
end
return Rules
