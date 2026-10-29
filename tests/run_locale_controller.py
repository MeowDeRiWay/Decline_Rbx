"""Exercise the real GUI binder with profile locales, text changes and opaque user text."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/client/LocaleController.luau').read_text()
source=re.sub(r'local (Rules|Catalog|Journal)=require[^\n]+\n','',source)
assert 'PreferredLanguage' not in source and 'AddSelector' not in source and 'DataStore' not in source
setup='''
local function signal()
 local handlers={}
 return {Connect=function(_,fn) handlers[fn]=true;return {Disconnect=function() handlers[fn]=nil end} end,
 Fire=function(_,...) for fn in pairs(handlers) do fn(...) end end}
end
local writes=0
local oldIndex,oldWrite=meta.__index,meta.__newindex
meta.__index=function(o,k)
 local values=rawget(o,"_values")
 if values and values[k]~=nil then return values[k] end
 return oldIndex(o,k)
end
meta.__newindex=function(o,k,v)
 if k=="Text" or k=="PlaceholderText" or k=="LocaleId" then
  local values=rawget(o,"_values") or {};rawset(o,"_values",values)
  local before=values[k];values[k]=v
  if before~=v then
   writes+=1
   local signals=rawget(o,"propertySignals")
   if signals and signals[k] then signals[k]:Fire() end
  end
  return
 end
 oldWrite(o,k,v)
 if k=="Parent" and v then
  local ancestor=v
  while ancestor do
   if ancestor.DescendantAdded then ancestor.DescendantAdded:Fire(o) end
   ancestor=ancestor.Parent
  end
 end
end
local oldIsA=methods.IsA
function methods:IsA(class)
 if class=="GuiBase2d" then return self.ClassName=="TextLabel" or self.ClassName=="TextBox" or self.ClassName=="TextButton" or self.ClassName=="ScreenGui" end
 return oldIsA(self,class)
end
function methods:GetPropertyChangedSignal(k)
 self.propertySignals=self.propertySignals or {};self.propertySignals[k]=self.propertySignals[k] or signal();return self.propertySignals[k]
end
function methods:GetAttributeChangedSignal(k)
 self.attributeSignals=self.attributeSignals or {};self.attributeSignals[k]=self.attributeSignals[k] or signal();return self.attributeSignals[k]
end
local oldNew=Instance.new
Instance.new=function(class)
 local o=oldNew(class);o.Destroying=signal();o.DescendantAdded=signal();o.Text="";o.PlaceholderText=""
 if class=="BindableEvent" then o.Event=signal();function o:Fire(...) self.Event:Fire(...) end end
 return o
end
local oldDestroy=methods.Destroy
function methods:Destroy() self.Destroying:Fire();oldDestroy(self) end
Players.LocalPlayer=a;a.LocaleId="uk-UA"
local playerGui=make("PlayerGui","PlayerGui",a)
local gui=make("ScreenGui","TestUI",playerGui)
local initial=make("TextLabel","Initial",nil);initial.Text="Take all";initial.Parent=gui
'''
cases='''
assert(Service.Language()=="uk" and initial.Text=="Взяти все" and initial.AutoLocalize==false)
local box=make("TextBox","ChatInput",gui);box.Text="Doctor";box.PlaceholderText="Search item name or ID"
assert(box.Text=="Doctor" and box.PlaceholderText=="Назва або ID предмета","never mutate player input")
local private=make("TextLabel","PlayerName",gui);private.Text="Doctor";private:SetAttribute("LocalizationIgnore",true)
assert(private.Text=="Doctor","marking user text restores original source")
local dynamic=make("TextLabel","Dynamic",gui)
Service.Set(dynamic,"Text","HP 040");assert(dynamic.Text=="ОЗ 040")
local before=writes
for i=1,1000 do Service.Set(dynamic,"Text","HP 040") end
assert(writes==before,"unchanged English source cannot cause translated write loops")
Service.Set(dynamic,"Text","Mayor: "..Service.Raw("Doctor"));assert(dynamic.Text=="Мер: Doctor")
a.LocaleId="ru-RU"
assert(Service.Language()=="ru" and initial.Text=="Взять всё" and box.PlaceholderText=="Название или ID предмета")
assert(private.Text=="Doctor" and box.Text=="Doctor")
initial.Text="Set price";assert(initial.Text=="Установить цену","new server/client text translates immediately")
a.LocaleId="en-us"
assert(initial.Text=="Set price" and dynamic.Text=="Mayor: Doctor","English source restored without internal tokens")
a.LocaleId="fr-fr";assert(Service.Language()=="en")
a.LocaleId="uk"
local combat=make("TextLabel","Combat",gui)
local event={ActorName="Doctor",ActorUserId=999,TargetName="Other",TargetUserId=a.UserId,Damage=25,AttackKind="Ranged",Critical=true,Knockout=true}
Service.Computed(combat,function() return Service.Combat(event,a.UserId) end)
assert(combat.Text:find("Doctor → Ви:",1,true) and combat.Text:find("25 ОЗ",1,true) and combat.Text:find("Ціль непритомна.",1,true))
a.LocaleId="ru"
assert(combat.Text:find("Doctor → Вы:",1,true) and combat.Text:find("Цель без сознания.",1,true))
local dead=initial;dead:Destroy();before=writes
a.LocaleId="uk";assert(initial.Text=="Установить цену","destroyed UI is disconnected")
print("PASS: profile-only locale, existing/new GUI, original source restoration, input/name protection, no write loops, combat and destroy cleanup")
'''
parts=[(root/'tests/fixtures/town_mock.luau').read_text(),setup,'local Rules=(function()\n'+(root/'src/shared/LocalizationRules.luau').read_text()+'\nend)()', 'local Journal=(function()\n'+(root/'src/shared/JournalPresentation.luau').read_text()+'\nend)()','local Catalog={}']
for p in sorted((root/'src/shared/Locales').glob('*.luau')):parts.append('table.insert(Catalog,(function()\n'+p.read_text()+'\nend)())')
hover=(root/'src/client/WorldItems.client.luau').read_text()
hover=hover[hover.index('Cursor.Subscribe("WorldItems",1,function()')+len('Cursor.Subscribe("WorldItems",1,function()'):hover.index('end)\nUserInputService.InputBegan')]
hover_setup=r'''
local Locale=Service
local player=a;player:LoadCharacterAsync()
local label=make("TextLabel","HoverRegression",gui)
local highlight={}
local hovered,reachable,chestHovered,stoveHovered,farmHovered,bedHovered,tradeHovered
local function dims(x,y) return {X={Offset=x},Y={Offset=y}} end
local UDim2={fromOffset=dims}
local Color3={fromRGB=function(r,g,b) return {r,g,b} end}
local Config={PickupDistance=1}
local distance=3
local Interaction={NearestPoint=function() return Vector3.new(distance,0,0) end}
local Stations={Kind=function() return nil end}
local GuiService={MenuIsOpen=false}
local UserInputService={GetMouseLocation=function() return {X=350,Y=300} end,GetFocusedTextBox=function() return nil end}
workspace.CurrentCamera={ViewportSize={X=800,Y=600}}
player.Character.HumanoidRootPart.Position=Vector3.zero
local body=make("Model","Zombie",workspace)
body:SetAttribute("IsCorpse",true);body:SetAttribute("ClientVisible",true);body:SetAttribute("DisplayName","Zombie")
local part=make("Part","Head",body)
local Cursor={Get=function() return {Hit={Instance=part}} end}
local folder=make("Folder","WorldItems",workspace)
'''
hover_cases=r'''
updateHover()
assert(label.Text:find("Зомбі",1,true) and label.Text:find("Занадто далеко",1,true))
local before=writes
for _=1,300 do updateHover() end
assert(writes==before,"actual corpse tooltip cannot alternate English/Ukrainian at 30Hz")
distance=0;updateHover()
assert(Service.Source(label,"Text")=="Zombie corpse\n[E] Loot")
before=writes;for _=1,300 do updateHover() end;assert(writes==before)
body.Name="GardenBed";body:SetAttribute("IsCorpse",nil)
body:SetAttribute("Watering",25);body:SetAttribute("PlantCount",2)
updateHover()
assert(Service.Source(label,"Text"):find("Water: 25/100",1,true),"multiline garden tooltip is assembled before translation")
before=writes;for _=1,300 do updateHover() end;assert(writes==before,"garden tooltip writes one complete source, without intermediate text")
body:SetAttribute("Watering",30);updateHover();assert(writes==before+1,"changed values still refresh exactly once")
a.LocaleId="ru";updateHover();before=writes
for _=1,300 do updateHover() end;assert(writes==before,"Russian hover stays stable too")
print("PASS: actual corpse and garden hover callbacks, stable translated text across 1200+ updates and changed-value refresh")
'''
parts+=['local Service=(function()\n'+source+'\nend)()',cases,hover_setup,'local function updateHover()\n'+hover+'\nend',hover_cases]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'controller.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
