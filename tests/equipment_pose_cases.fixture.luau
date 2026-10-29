function methods:GetChildren()
 local result={};for _,v in ipairs(objects) do if not v.Deleted and v.Parent==self then table.insert(result,v) end end;return result
end
function methods:Clone()
 local copy=Instance.new(self.ClassName)
 copy.Name=self.Name;copy.Size=self.Size;copy.CFrame=self.CFrame
 copy.Attributes=table.clone(self.Attributes)
 return copy
end
function methods:PivotTo(frame) self.CFrame=frame end
local serverStorage=Instance.new("Folder")
local templates=Instance.new("Folder",serverStorage);templates.Name="Items"
for _,id in ipairs({"Pistol9mm","PipePistol9mm","Rifle223","IronAxe","IronShovel","IronKnife"}) do
 local part=Instance.new("Part",templates);part.Name=id;part.CFrame=CFrame.identity;part.Size=Vector3.new(.1,.1,.5)
end
