do
 local old, replacement = Instance.new("Model"), Instance.new("Model")
 local chest = Instance.new("Model"); chest.Name="Chest"; chest.Parent=old
 local storage = {TreeLog=7, Scrap=13}
 local contents = {[chest]=storage}
 local target = Instance.new("Model"); target.Name="Chest"; target.Parent=replacement
 target:PivotTo(CFrame.new(Vector3.new(20,0,10)))
 local migrate=assert(BuildingStorage.PrepareUpgrade(old,replacement))
 assert(chest.Parent==old and not target.destroyed, "preflight must not mutate buildings")
 migrate()
 assert(chest.Parent==replacement and target.destroyed)
 assert(contents[chest]==storage and storage.TreeLog==7 and storage.Scrap==13, "live storage identity retained")
 assert(chest:GetPivot()==target:GetPivot(), "chest must move to upgraded placement")
 local missing=Instance.new("Model")
 assert(BuildingStorage.PrepareUpgrade(replacement,missing)==nil, "missing chest must block upgrade")
 assert(chest.Parent==replacement, "failed upgrade keeps original chest")
 local second=Instance.new("Model"); second.Name="Chest"; second.Parent=replacement
 local nextBuilding=Instance.new("Model")
 for _,id in ipairs({"Tools","Materials"}) do
  local c=Instance.new("Model"); c.Name="Chest"; c:SetAttribute("StorageID",id); c.Parent=nextBuilding
 end
 chest:SetAttribute("StorageID","Materials"); second:SetAttribute("StorageID","Tools")
 assert(BuildingStorage.PrepareUpgrade(replacement,nextBuilding))()
 assert(chest.Parent==nextBuilding and second.Parent==nextBuilding)
 print("PASS: upgrade preserves chest identity, contents and placement; missing chest rejected; multiple chests matched by StorageID")
end

local oldMarket=make("Model","OldMarket",workspace)
local oldPost=make("Model","TradePost",oldMarket,{TradePostID="counter-1",TradeOwnerID=101,TradeHasStock=true})
make("Part","Part",oldPost)
local newMarket=make("Model","NewMarket",workspace)
local newPost=make("Model","TradePost",newMarket,{TradePostID="counter-1"});make("Part","Part",newPost)
newPost.CFrame=CFrame.new(Vector3.new(7,0,9))
assert(not BuildingStorage.CanDestroy(oldMarket),"occupied trade post blocks destructive demolition")
local migratePost=assert(BuildingStorage.PrepareUpgrade(oldMarket,newMarket));migratePost()
assert(oldPost.Parent==newMarket and newPost.destroyed and oldPost:GetAttribute("TradeOwnerID")==101 and oldPost:GetAttribute("TradeHasStock"),"upgrade preserves live post identity and seller state")
assert(oldPost:GetPivot().Position.X==7 and oldPost:GetPivot().Position.Z==9,"post moves to upgraded counter position")
local missingPost=make("Model","MissingPost",workspace)
assert(not BuildingStorage.PrepareUpgrade(newMarket,missingPost),"upgrade cannot silently discard trade stock")
print("PASS: trade posts survive building upgrades, preserve ownership/state, reject missing replacements and block destructive demolition")
