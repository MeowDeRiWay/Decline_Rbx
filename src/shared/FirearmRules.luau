local Rules={}
-- Gameplay resistance: additional range consumed per stud of material.
Rules.Resistance={Glass=15,Wood=180,Aluminum=180,Brick=1800,Concrete=3200,Metal=9000,ArmorSteel=24000}
function Rules.AmmoID(caliber,kind)
 return (caliber=="223" or caliber=="9mm" or caliber=="308") and (kind=="FMJ" or kind=="AP") and ("Ammo"..caliber..kind) or nil
end
function Rules.BoxCount(maximum,roll)
 if typeof(maximum)~="number" or maximum~=maximum or maximum<1 or maximum==math.huge then return nil end
 return math.clamp(math.floor(roll*math.min(10000,math.floor(maximum)))+1,1,math.min(10000,math.floor(maximum)))
end
-- FMJ and AP use the same world-material budget. Caliber sets material access.
function Rules.Cost(material,thickness,caliber)
 if material=="Brick" and caliber~="223" and caliber~="308" then return math.huge end
 if material=="Concrete" and caliber~="308" then return math.huge end
 local resistance=Rules.Resistance[material]
 if not resistance then return math.huge end
 return thickness*(1+resistance)
end
function Rules.ArmorIgnore(caliber,kind)
 if caliber=="223" then return kind=="AP" and 3 or 2,kind=="AP" and .15 or .1 end
 if caliber=="308" then return 5,kind=="AP" and .4 or .2 end
 -- No 9 mm armor-ignore values have been specified yet.
 return 0,0
end
-- Slab intersection in Part local coordinates; returns path distances, not bbox size.
function Rules.Interval(origin,direction,frame,size)
 local p,d=frame:PointToObjectSpace(origin),frame:VectorToObjectSpace(direction)
 local near,far=-math.huge,math.huge
 for _,axis in ipairs({"X","Y","Z"}) do
  local half=size[axis]/2
  if math.abs(d[axis])<1e-8 then if math.abs(p[axis])>half then return nil end
  else
   local a,b=(-half-p[axis])/d[axis],(half-p[axis])/d[axis]
   if a>b then a,b=b,a end
   near,far=math.max(near,a),math.min(far,b)
   if near>far then return nil end
  end
 end
 if far<0 then return nil end
 return math.max(0,near),far
end
function Rules.Merge(intervals)
 table.sort(intervals,function(a,b) return a[1]<b[1] end)
 local result={}
 for _,span in ipairs(intervals) do
  local previous=result[#result]
  if previous and span[1]<=previous[2]+.00001 then previous[2]=math.max(previous[2],span[2])
  else table.insert(result,{span[1],span[2]}) end
 end
 return result
end
return Rules
