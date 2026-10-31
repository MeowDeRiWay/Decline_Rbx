"""Actual exchange client: invitation, offer editing and revision confirmation."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/client/PlayerExchange.client.luau').read_text()
source=re.sub(r'local (Locale|Theme|Items)=require[^\n]+\n','',source)
setup='''
Players.LocalPlayer=a;a.CharacterRemoving=event()
local playerGui=make("PlayerGui","PlayerGui",a)
local oldNew=Instance.new
Instance.new=function(class)
 local o=oldNew(class)
 if class=="TextButton" then o.Activated=event() end
 return o
end
function methods:IsFocused() return false end
local UDim2={new=function(...) return {...} end,fromScale=function(...) return {...} end,fromOffset=function(...) return {...} end}
local UDim={new=function(...) return {...} end}
local Vector2={new=function(...) return {...} end}
Enum.AutomaticSize={Y=1};Enum.SortOrder={LayoutOrder=1};Enum.TextXAlignment={Left=1};Enum.KeyCode={Q=1,Escape=2}
local Input={InputBegan=event(),GetFocusedTextBox=function() return nil end}
local realService=game.GetService
function game:GetService(name) if name=="UserInputService" then return Input end;return realService(self,name) end
local Locale={Raw=function(value) return value end}
local Theme={Bevel=function() end}
local Items={Plank={Name="Plank"}}
local folder=make("Folder","PlayerExchangeRemotes",ReplicatedStorage)
local action=make("RemoteEvent","Action",folder)
local sent={}
function action:FireServer(...) table.insert(sent,{...}) end
local state=make("RemoteEvent","State",folder);state.OnClientEvent=event()
a:SetAttribute("MoneyReady",true);a:SetAttribute("Money",100)
'''
cases='''
local gui=playerGui.PlayerExchangeUI
local function find(text)
 for _,o in ipairs(gui:GetDescendants()) do if o:IsA("TextButton") and o.Text==text then return o end end
 error("button missing: "..text)
end
local value={Open=true,ID=10,Phase="Invite",Incoming=true,PartnerName="Partner",Revision=1,Cash=0,OtherCash=0,Inventory={},Offer={},OtherOffer={},ConfirmAt=clock+2}
state.OnClientEvent:Fire(value)
assert(gui.Enabled and a:GetAttribute("ExchangeOpen"))
find("Accept exchange").Activated:Fire();assert(sent[#sent][1]=="Join" and sent[#sent][2]==10)
value.Phase="Offer";value.Revision=2;value.Inventory={{ID="Plank",Key="Plank",Count=5}}
state.OnClientEvent:Fire(value)
assert(find("Review the offer...").Active==false)
find("Add to offer").Activated:Fire();assert(sent[#sent][1]=="Offer" and sent[#sent][3]=="Plank" and sent[#sent][4]==1)
local boxes={}
for _,o in ipairs(gui:GetDescendants()) do if o:IsA("TextBox") then table.insert(boxes,o) end end
assert(#boxes==2);boxes[1].Text="25";find("Offer money").Activated:Fire();assert(sent[#sent][1]=="Cash" and sent[#sent][3]==25)
tick(3);find("Confirm exchange").Activated:Fire();assert(sent[#sent][1]=="Confirm" and sent[#sent][3]==2,"latest revision sent")
value.Confirmed=true;state.OnClientEvent:Fire(value);assert(find("Waiting for partner").Active==false)
value.Confirmed=false;value.Revision=3;value.Cash=25;value.Offer={{ID="Plank",Key="Plank",Count=1}};state.OnClientEvent:Fire(value)
find("Remove from offer").Activated:Fire();assert(sent[#sent][1]=="Offer" and sent[#sent][4]==0)
find("Cancel").Activated:Fire();assert(not gui.Enabled and not a:GetAttribute("ExchangeOpen") and sent[#sent][1]=="Cancel")
state.OnClientEvent:Fire(value);a:SetAttribute("MapOpen",true);assert(not gui.Enabled and sent[#sent][1]=="Cancel","opening another modal cancels")
a:SetAttribute("MapOpen",false);state.OnClientEvent:Fire(value);a.CharacterRemoving:Fire();assert(not gui.Enabled)
state.OnClientEvent:Fire(value);state.OnClientEvent:Fire({Open=false});assert(not gui.Enabled and not a:GetAttribute("ExchangeOpen"))
print("PASS: actual client invitation, quantities, cash entry, review delay, revision confirmation, cancellation and modal guards")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'ui.luau';p.write_text((root/'tests/fixtures/town_mock.luau').read_text()+'\n'+setup+'\n'+source+'\n'+cases)
 subprocess.run([sys.argv[1],str(p)],check=True)
