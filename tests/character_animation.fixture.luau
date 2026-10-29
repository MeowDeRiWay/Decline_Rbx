local function signal()
 local callbacks={}
 return {Connect=function(_,fn) callbacks[fn]=true;return {Disconnect=function() callbacks[fn]=nil end} end,Fire=function(_,...) for fn in pairs(callbacks) do fn(...) end end}
end
local deferred={}
task={defer=function(fn) table.insert(deferred,fn) end}
local function flush() local pending=deferred;deferred={};for _,fn in ipairs(pending) do fn() end end
workspace={}
function methods:IsDescendantOf(target) local p=self.Parent;while p do if p==target then return true end;p=p.Parent end;return false end
local find=methods.FindFirstChild
function methods:FindFirstChild(name,recurse)
 if not recurse then return find(self,name) end
 for _,v in ipairs(self:GetDescendants()) do if v.Name==name then return v end end
end
function methods:GetAttributeChangedSignal(key) self.Signals=self.Signals or {};self.Signals[key]=self.Signals[key] or signal();return self.Signals[key] end
function methods:GetPivot() return self.CFrame end
local function makePlayer(x)
 local c=Instance.new("Model",workspace)
 for _,g in ipairs(geometry) do local p=Instance.new("Part",c);p.Name=g.Name;p.Size=g.Size;p.CFrame=CFrame.new(x-586,6.25,0)*g.CFrame end
 local root=c:FindFirstChild("Body");root.Name="HumanoidRootPart"
 local hp=Instance.new("Humanoid",c);hp.Health=100;hp.WalkSpeed=1
 Rig.Prepare(c,root,hp)
 c.DescendantAdded=signal();c.DescendantRemoving=signal()
 local player={Character=c,CharacterAdded=signal(),CharacterRemoving=signal()}
 return player,c,root,hp
end
local owner,c,root,hp=makePlayer(0)
local other,oc,otherRoot=makePlayer(1)
local Players={LocalPlayer=owner,PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return {owner,other} end}
local RunService={PreSimulation=signal()}
local Items={Gun={Firearm={Category="Rifle"}},Pistol={Firearm={Category="Pistol"}},Knife={Weapon={}},Axe={Weapon={},HarvestTool="Axe"},Shovel={Weapon={},HarvestTool="Shovel"}}
game={GetService=function(_,name) if name=="Players" then return Players elseif name=="RunService" then return RunService end end}
