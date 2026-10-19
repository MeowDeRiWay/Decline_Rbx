local Random={new=function() return {NextInteger=function(_,low) return low end, NextNumber=function() return .5 end} end}
-- Geometry mock below replaces the setup's CFrame for new test markers.

local function warn() end
local baseNew=Instance.new
function Instance.new(class)
 local object=baseNew(class); object.CFrame=CFrame.new(); return object
end
local baseClone=methods.Clone
function methods:Clone()
 local clone=baseClone(self); clone.CFrame=self.CFrame; clone.Size=self.Size
 return clone
end
function methods:PivotTo(target)
 local delta=target*self.CFrame:ToObjectSpace(CFrame.new())
 for _,descendant in ipairs(self:GetDescendants()) do descendant.CFrame=delta*descendant.CFrame end
 self.CFrame=target
end
