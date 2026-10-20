local Presentation={}
function Presentation.Plain(text)
 return (tostring(text):gsub("<[^>]->", ""):gsub("&lt;","<"):gsub("&gt;",">"):gsub("&quot;",'"'):gsub("&apos;","'"):gsub("&amp;","&"))
end
function Presentation.Combat(event)
 local actor,target=event.ActorName,event.TargetName
 if event.Kind=="Miss" then return string.format("%s missed %s.",actor,target) end
 if event.Kind=="Dodge" then return string.format("%s dodged %s's attack.",target,actor) end
 local action=event.AttackKind=="Ranged" and "shot" or "hit"
 local text=string.format("%s %s %s for %d HP%s.",actor,action,target,math.floor(math.max(0,event.Damage or 0)+.5),event.Critical and " (critical)" or "")
 if event.Killed then text=text:sub(1,-2).." and killed them."
 elseif event.Knockout then text..=" "..target.." was knocked unconscious." end
 return text
end
return Presentation
