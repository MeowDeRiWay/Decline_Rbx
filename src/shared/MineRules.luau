local Rules={ArmDelay=5,WorkDuration=2.5,TriggerRadius=.7,MaxDetection=20}
function Rules.Skill(value) return math.clamp(tonumber(value) or 0,0,300) end
function Rules.DisarmChance(skill,placed,own)
 if own then return 1 end
 return math.clamp(.9+(Rules.Skill(skill)-Rules.Skill(placed))*.0085,.05,1)
end
function Rules.DetectionRadius(attention,skill)
 return 20*(.25*math.clamp(tonumber(attention) or 0,0,10)/10+.75*Rules.Skill(skill)/300)
end
function Rules.Crossed(previous,current,point,height)
 previous=previous or current
 if (current-previous).Magnitude>20 then previous=current end
 local a,b=Vector3.new(previous.X,0,previous.Z),Vector3.new(current.X,0,current.Z)
 local delta=b-a
 local p=Vector3.new(point.X,0,point.Z)
 local t=delta:Dot(delta)>.00001 and math.clamp((p-a):Dot(delta)/delta:Dot(delta),0,1) or 1
 local y=previous.Y+(current.Y-previous.Y)*t
 return (a+delta*t-p).Magnitude<=Rules.TriggerRadius and y>=point.Y-.2 and y-point.Y<=height
end
return Rules
