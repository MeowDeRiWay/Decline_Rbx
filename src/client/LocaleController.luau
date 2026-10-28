-- Event-driven manual localization; gameplay IDs and server payloads stay English.
local Players=game:GetService("Players")
local Replicated=game:GetService("ReplicatedStorage")
local Journal=require(Replicated.Shared.JournalPresentation)
local Rules=require(Replicated.Shared.LocalizationRules)
local Catalog=require(Replicated.Shared.LocalizationCatalog)
local dictionary=Rules.New(Catalog)
local player=Players.LocalPlayer
local Service={}
local locale=Rules.Normalize(player.LocaleId)
local records=setmetatable({},{__mode="k"})
local changed=Instance.new("BindableEvent")
Service.Changed=changed.Event
local function ignored(object)
 local current=object
 while current and current~=player do
  if current:GetAttribute("LocalizationIgnore")==true then return true end
  current=current.Parent
 end
 return false
end
Service.Raw=Rules.Protect
function Service.Language() return locale end
function Service.Text(text) return dictionary.Translate(text,locale) end
local function render(object,record)
 if record.Busy then return end
 record.Busy=true
 for key,entry in pairs(record.Fields) do
  local value=record.Computed and record.Computed() or (ignored(object) and entry.Source or Service.Text(entry.Source))
  entry.Rendered=value
  if object[key]~=value then object[key]=value end
 end
 record.Busy=false
end
local function bind(object)
 if records[object] then return records[object] end
 if object:IsA("GuiBase2d") then object.AutoLocalize=false end
 local keys=object:IsA("TextBox") and {"PlaceholderText"} or
  ((object:IsA("TextLabel") or object:IsA("TextButton")) and {"Text"} or nil)
 if not keys then return end
 local record={Fields={},Connections={}}
 records[object]=record
 for _,key in ipairs(keys) do
  record.Fields[key]={Source=object[key]}
  table.insert(record.Connections,object:GetPropertyChangedSignal(key):Connect(function()
   if record.Busy then return end
   local entry=record.Fields[key]
   if object[key]~=entry.Rendered then entry.Source=object[key];render(object,record) end
  end))
 end
 table.insert(record.Connections,object:GetAttributeChangedSignal("LocalizationIgnore"):Connect(function() render(object,record) end))
 table.insert(record.Connections,object.Destroying:Connect(function()
  for _,connection in ipairs(record.Connections) do connection:Disconnect() end
  records[object]=nil
 end))
 render(object,record)
 return record
end
function Service.Set(object,key,value)
 if key~="Text" and key~="PlaceholderText" then if object[key]~=value then object[key]=value end;return end
 local record=bind(object)
 if not record or not record.Fields[key] then if object[key]~=value then object[key]=value end;return end
 local entry=record.Fields[key]
 if entry.Source==value then return end
 entry.Source=value;render(object,record)
end
function Service.Source(object,key)
 local record=records[object]
 return record and record.Fields[key] and record.Fields[key].Source or object[key]
end
function Service.Computed(object,callback)
 local record=bind(object)
 if record then record.Computed=callback;render(object,record) end
end
function Service.Combat(event,viewerId)
 if locale=="en" then return Journal.Combat(event,viewerId) end
 local uk=locale=="uk"
 local function name(id,value,creature)
  if id==viewerId then return uk and "Ви" or "Вы" end
  return creature and Service.Text(value) or value
 end
 local actor=name(event.ActorUserId,event.ActorName,event.ActorIsCreature) or "?"
 local target=name(event.TargetUserId,event.TargetName,event.TargetIsCreature) or "?"
 local action
 if event.Kind=="Miss" then action=uk and "промах" or "промах"
 elseif event.Kind=="Dodge" then action=uk and "ухилення" or "уклонение"
 else
  action=(event.AttackKind=="Ranged" and (uk and "постріл" or "выстрел") or (uk and "удар" or "удар"))..
   " · "..math.floor(math.max(0,event.Damage or 0)+.5).." ОЗ"..
   (event.Critical and (uk and " (критичний)" or " (критический)") or "")
 end
 local text=actor.." → "..target..": "..action.."."
 if event.Killed then text..=uk and " Ціль загинула." or " Цель погибла."
 elseif event.Knockout then text..=uk and " Ціль непритомна." or " Цель без сознания." end
 return text
end
function Service.RefreshLocale()
 local code=Rules.Normalize(player.LocaleId)
 if locale==code then return end
 locale=code
 for object,record in pairs(records) do if object.Parent then render(object,record) end end
 changed:Fire(code)
end
function Service.Start()
 if Service.Started then return end;Service.Started=true
 local gui=player:WaitForChild("PlayerGui")
 for _,object in ipairs(gui:GetDescendants()) do bind(object) end
 gui.DescendantAdded:Connect(bind)
 player:GetPropertyChangedSignal("LocaleId"):Connect(Service.RefreshLocale)
 Service.RefreshLocale()
end
Service.Start()
return Service
