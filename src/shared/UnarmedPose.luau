-- Accepted punches are timestamped by the server; all viewers sample one timeline.
local Punch={Contact=.25}
function Punch.Begin(character,now)
 character:SetAttribute("PunchSequence",(character:GetAttribute("PunchSequence") or 0)+1)
 character:SetAttribute("PunchStartedAt",now)
end
function Punch.Target(size,side,sequence,elapsed)
 if elapsed<0 or elapsed>=1.5 then return nil end
 local sign=side=="Left" and -1 or 1
 local guard=Vector3.new(sign*size.X*.55,size.Y*.35,-size.Y*.45)
 local striking=side==((sequence%2==1) and "Right" or "Left")
 local target=guard
 if striking and elapsed<Punch.Contact then
  -- First chamber the fist, then extend to contact at the existing damage time.
  local chamber=Vector3.new(sign*size.X*.65,size.Y*.31,-size.Y*.30)
  if elapsed<.1 then
   target=guard+(chamber-guard)*(elapsed/.1)
  else
   local reach=Vector3.new(sign*size.X*.35,size.Y*.35,-size.Y*1.05)
   target=chamber+(reach-chamber)*((elapsed-.1)/(Punch.Contact-.1))
  end
 elseif striking and elapsed<.5 then
  local reach=Vector3.new(sign*size.X*.35,size.Y*.35,-size.Y*1.05)
  target=reach+(guard-reach)*((elapsed-Punch.Contact)/(.5-Punch.Contact))
 end
 -- Stay in guard between repeated punches, then smoothly lower both arms.
 local weight=elapsed<=1.25 and 1 or (1.5-elapsed)/.25
 return target,weight
end
return Punch
