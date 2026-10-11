local Rules = {}
function Rules.InSector(forwardX,forwardZ,offsetX,offsetZ,angle)
 local distance = math.sqrt(offsetX*offsetX+offsetZ*offsetZ)
 local forwardLength = math.sqrt(forwardX*forwardX+forwardZ*forwardZ)
 if distance < .0001 then return true end
 if forwardLength < .0001 then return false end
 local dot = (forwardX*offsetX+forwardZ*offsetZ)/(distance*forwardLength)
 return dot >= math.cos(math.rad(angle/2)) - 1e-7
end
return Rules
