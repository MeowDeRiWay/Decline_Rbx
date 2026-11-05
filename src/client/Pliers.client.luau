local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local Cursor=require(script.Parent.CursorQuery)
local Interaction=require(Storage.Shared.Interaction)
local Items=require(Storage.Shared.ItemConfig)
local player=Players.LocalPlayer
local remote=Storage:WaitForChild("ResourceAction")
local movement={W=true,A=true,S=true,D=true,Up=true,Down=true,Left=true,Right=true}
Input.InputBegan:Connect(function(input,processed)
 local c=player.Character
 if processed or not c or Input:GetFocusedTextBox() or GuiService.MenuIsOpen then return end
 if c:GetAttribute("DismantlingScrap") and movement[input.KeyCode.Name] then remote:FireServer("Cancel");return end
 if input.UserInputType~=Enum.UserInputType.MouseButton1 or c:GetAttribute("HandsItem")~="Pliers" or c:GetAttribute("InteractionLocked") or c:GetAttribute("Knockout") or c:GetAttribute("IsDead") or c:GetAttribute("HandsBusy") or c:GetAttribute("MedicalHeld") then return end
 for _,name in ipairs({"InventoryOpen","PlayerContextOpen","TownMenuOpen","ProgressionOpen","GroupOpen","MapOpen","HelpOpen","TradeOpen","ExchangeOpen","AdminOpen","MedicalMode"}) do if player:GetAttribute(name) then return end end
 local root=c:FindFirstChild("HumanoidRootPart")
 local sample=Cursor.Get();local object=sample and sample.Hit and sample.Hit.Instance
 while root and object and object~=workspace do
  if object:GetAttribute("ResourceType")=="ScrapPile" then
   if Interaction.Distance(object,root.Position)<=Items.PickupDistance then remote:FireServer("Dismantle",object) end
   return
  end
  object=object.Parent
 end
end)
