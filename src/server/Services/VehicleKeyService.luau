local Http=game:GetService("HttpService")
local Rules=require(game:GetService("ReplicatedStorage").Shared.InventoryRules)
local Inventory=require(script.Parent.InventoryService)
local Chests=require(script.Parent.ChestService)
local WorldItems=require(script.Parent.WorldItemService)
local Service={}
local records=setmetatable({},{__mode="k"})
function Service.Register(model)
 local record={ID=Http:GenerateGUID(false),Token=Http:GenerateGUID(false),Issued=false}
 records[model]=record
 model:SetAttribute("VehicleID",record.ID)
 model:SetAttribute("PublicAccess",true)
 return record
end
function Service.Refresh(model)
 local record=records[model]
 if not record then return false end
 if record.Issued and not Inventory.HasVehicleKey(record.Token)
  and not Chests.HasVehicleKey(record.Token) and not WorldItems.HasVehicleKey(record.Token) then
  record.Token=Http:GenerateGUID(false);record.Issued=false
  model:SetAttribute("OwnerID",nil)
  model:SetAttribute("PublicAccess",true)
 end
 return true
end
function Service.Allowed(player,model)
 local record=records[model]
 if not player or not record then return false end
 return not record.Issued or Rules.HasVehicleKey(Inventory.Export(player),record.Token)
end
function Service.Claim(player,model)
 local record=records[model]
 if not player or not record then return false end
 Service.Refresh(model)
 if record.Issued then return Rules.HasVehicleKey(Inventory.Export(player),record.Token) end
 local data={VehicleKey=record.Token,VehicleID=record.ID,VehicleName=model:GetAttribute("DisplayName") or "Vehicle"}
 if not Inventory.Add(player,"VehicleKey",1,nil,{data}) then return false end
 record.Issued=true
 model:SetAttribute("OwnerID",nil)
 model:SetAttribute("PublicAccess",false)
 return true
end
function Service.Forget(model) records[model]=nil end
return Service
