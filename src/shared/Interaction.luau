local Interaction = {}
function Interaction.NearestPoint(object, position)
 local frame,size
 if object:IsA("Model") then frame,size = object:GetBoundingBox()
 else frame,size = object.CFrame,object.Size end
 local point,half = frame:PointToObjectSpace(position),size/2
 return frame:PointToWorldSpace(Vector3.new(math.clamp(point.X,-half.X,half.X),math.clamp(point.Y,-half.Y,half.Y),math.clamp(point.Z,-half.Z,half.Z)))
end
function Interaction.Distance(object, position)
 return (Interaction.NearestPoint(object,position)-position).Magnitude
end
-- Closest points of two oriented bounding boxes: vertex/face and edge/edge
-- features cover separated boxes, including rotated, elongated workstations.
function Interaction.ClosestPoints(first,second)
 local function box(object)
  local frame,size
  if object:IsA("Model") then frame,size=object:GetBoundingBox() else frame,size=object.CFrame,object.Size end
  local corners,edges={},{}
  for x=0,1 do for y=0,1 do for z=0,1 do
   table.insert(corners,frame:PointToWorldSpace(Vector3.new((x-.5)*size.X,(y-.5)*size.Y,(z-.5)*size.Z)))
  end end end
  for i=0,7 do for _,step in ipairs({1,2,4}) do
   if math.floor(i/step)%2==0 then table.insert(edges,{corners[i+1],corners[i+step+1]}) end
  end end
  return corners,edges
 end
 local a,ae=box(first)
 local b,be=box(second)
 local bestA,bestB,best
 local function consider(p,q)
  local distance=(p-q).Magnitude
  if not best or distance<best then bestA,bestB,best=p,q,distance end
 end
 local function crossing(edges,object)
  local frame,size
  if object:IsA("Model") then frame,size=object:GetBoundingBox() else frame,size=object.CFrame,object.Size end
  for _,edge in ipairs(edges) do
   local start=frame:PointToObjectSpace(edge[1])
   local delta=frame:VectorToObjectSpace(edge[2]-edge[1])
   local low,high=0,1
   for _,axis in ipairs({"X","Y","Z"}) do
    local half=size[axis]/2
    if math.abs(delta[axis])<1e-10 then
     if math.abs(start[axis])>half then high=-1;break end
    else
     local near,far=(-half-start[axis])/delta[axis],(half-start[axis])/delta[axis]
     if near>far then near,far=far,near end
     low,high=math.max(low,near),math.min(high,far)
    end
   end
   if low<=high then return edge[1]+(edge[2]-edge[1])*low end
  end
 end
 local overlap=crossing(ae,second) or crossing(be,first)
 if overlap then return overlap,overlap,0 end
 for _,p in ipairs(a) do consider(p,Interaction.NearestPoint(second,p)) end
 for _,q in ipairs(b) do consider(Interaction.NearestPoint(first,q),q) end
 for _,edgeA in ipairs(ae) do for _,edgeB in ipairs(be) do
  local p,q=edgeA[1],edgeB[1]
  local u,v=edgeA[2]-p,edgeB[2]-q
  local w=p-q
  local aa,bb,ab,aw,bw=u:Dot(u),v:Dot(v),u:Dot(v),u:Dot(w),v:Dot(w)
  local denominator=aa*bb-ab*ab
  local t=denominator>1e-10 and math.clamp((ab*bw-bb*aw)/denominator,0,1) or 0
  local h=bb>1e-10 and (ab*t+bw)/bb or 0
  if h<0 then h=0;t=aa>1e-10 and math.clamp(-aw/aa,0,1) or 0
  elseif h>1 then h=1;t=aa>1e-10 and math.clamp((ab-aw)/aa,0,1) or 0 end
  consider(p+u*t,q+v*h)
 end end
 return bestA,bestB,best
end
return Interaction
