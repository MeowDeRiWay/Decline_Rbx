local Presentation={}
function Presentation.Plain(text)
 return (tostring(text):gsub("<[^>]->", ""):gsub("&lt;","<"):gsub("&gt;",">"):gsub("&quot;",'"'):gsub("&apos;","'"):gsub("&amp;","&"))
end
function Presentation.Combat(event,viewerId)
 local own=viewerId~=nil and event.ActorUserId==viewerId
 local victim=viewerId~=nil and event.TargetUserId==viewerId
 local actor=own and "You" or (event.ActorIsCreature and (event.ActorName:sub(1,1):upper()..event.ActorName:sub(2):lower()) or event.ActorName)
 local target=victim and "you" or (event.TargetIsCreature and event.TargetName:lower() or event.TargetName)
 if event.Kind=="Miss" then return string.format("%s missed %s.",actor,target) end
 if event.Kind=="Dodge" then return string.format("%s dodged %s attack.",victim and "You" or (target:sub(1,1):upper()..target:sub(2)),own and "your" or ((event.ActorIsCreature and event.ActorName:lower() or actor).."'s")) end
 local action=event.AttackKind=="Ranged" and "shot" or "hit"
 local text=string.format("%s %s %s for %d HP%s.",actor,action,target,math.floor(math.max(0,event.Damage or 0)+.5),event.Critical and " (critical)" or "")
 if event.Killed then text=text:sub(1,-2).." and killed "..(victim and "you" or event.TargetIsCreature and "it" or "them").."."
 elseif event.Knockout then text..=" "..(victim and "You were" or (target.." was")).." knocked unconscious." end
 return text
end
return Presentation
