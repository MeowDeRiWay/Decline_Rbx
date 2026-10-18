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
