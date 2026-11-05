local Rules={}
function Rules.Frame(position,characterRight)
 -- Use character-right projected onto the ground. Character pitch/roll never tilts
 -- the listener's head into the floor, even with a directly overhead camera.
 local right=Vector3.new(characterRight.X,0,characterRight.Z)
 if right.Magnitude<.0001 then right=Vector3.new(1,0,0) else right=right.Unit end
 local forward=Vector3.new(right.Z,0,-right.X)
 return CFrame.lookAt(position,position+forward,Vector3.new(0,1,0))
end
return Rules
