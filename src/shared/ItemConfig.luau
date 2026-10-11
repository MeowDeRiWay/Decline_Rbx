-- Every new item must be registered here before any system grants it.
-- IDs are stable internal keys; Name is the English name shown in the UI.
local ItemConfig = {}
ItemConfig.PickupDistance = 1
ItemConfig.Slots = {"Head", "Body", "Hands", "Back", "Additional"}
ItemConfig.Items = {
 Knife = {
  Name = "Knife", Weight = 0.3, Slot = "Hands",
  Description = "A simple knife.",
  -- Optional HeldOffset = CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz),
  -- An Attachment named HandsGrip inside the character Body overrides this offset.
 },
 Potato = {
  Name = "Potato", Weight = 0.2,
  Description = "An ordinary raw potato. I recommend cooking it before eating.",
  Consume = {Food = 5, Sick = 5},
 },
 -- Example (remove the comment when you have this item):
 -- SmallBackpack = {Name = "Small Backpack", Weight = 1.5, Slot = "Back"},
 -- Metal = {Name = "Metal", Weight = 0.2},
}
return ItemConfig
