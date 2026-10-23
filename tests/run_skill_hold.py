"""Exercise actual skill press/hold handlers and all-perk UI rendering."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/client/Progression.client.luau').read_text()
hold=source[source.index('local heldSkill'):source.index('local function skillRow')]
rows=source[source.index(' local count=0\n -- All perks'):source.index('\nend\nsetOpen=function')]
setup='''
local function event()
 local e={callbacks={}}
 function e:Connect(fn) table.insert(self.callbacks,fn) end
 function e:Fire(...) for _,fn in ipairs(self.callbacks) do fn(...) end end
 return e
end
local time=0;local os={clock=function() return time end}
local Enum={UserInputType={MouseButton1=1,Touch=2}}
local Input={InputEnded=event(),WindowFocusReleased=event(),GetFocusedTextBox=function() return nil end}
local sent={}
local action={FireServer=function(_,command,id) table.insert(sent,{command,id}) end}
local panel={Visible=true};local mode="Skills"
local knocked=false
local player={Character={GetAttribute=function(_,key) return key=="Knockout" and knocked end}}
local snapshot={Confirmed=true,Stats={Strength=5,Attention=5,Endurance=5,Intelligence=5,Agility=5,Luck=5},Skills={Melee=25},SkillPoints=10,Perks={},PerkPoints=1}
local function object() return {InputBegan=event(),MouseLeave=event()} end
'''
cases='''
local b=object();bindSkillHold(b,"Melee")
local mouse={UserInputType=Enum.UserInputType.MouseButton1}
b.InputBegan:Fire(mouse);assert(#sent==1)
time=.34;repeatSkillHold();assert(#sent==1)
time=.35;repeatSkillHold();assert(#sent==2)
time=.49;repeatSkillHold();assert(#sent==2)
time=.51;repeatSkillHold();assert(#sent==3)
Input.InputEnded:Fire(mouse);time=1;repeatSkillHold();assert(#sent==3,"release stops repeat and adds no extra purchase")
b.InputBegan:Fire(mouse);b.MouseLeave:Fire();time=2;repeatSkillHold();assert(#sent==4)
b.InputBegan:Fire(mouse);Input.WindowFocusReleased:Fire();time=3;repeatSkillHold();assert(#sent==5)
b.InputBegan:Fire(mouse);panel.Visible=false;time=4;repeatSkillHold();assert(#sent==6)
panel.Visible=true;time=5;repeatSkillHold();assert(#sent==6,"reopening cannot resume an old hold")
b.InputBegan:Fire(mouse);mode="Stats";time=6;repeatSkillHold();assert(#sent==7)
mode="Skills";snapshot.SkillPoints=0;b.InputBegan:Fire(mouse);assert(#sent==7)
snapshot.SkillPoints=1;snapshot.Skills.Melee=100;b.InputBegan:Fire(mouse);assert(#sent==7,"higher skill tier costs are respected")
snapshot.SkillPoints=10;snapshot.Skills.Melee=300;b.InputBegan:Fire(mouse);assert(#sent==7,"skill cap respected")
snapshot.Skills.Melee=25;knocked=true;b.InputBegan:Fire(mouse);assert(#sent==7)
knocked=false
local touch={UserInputType=Enum.UserInputType.Touch}
b.InputBegan:Fire(touch);assert(#sent==8)
Input.InputEnded:Fire({UserInputType=Enum.UserInputType.Touch});time=7;repeatSkillHold();assert(#sent==9,"different finger does not end original hold")
Input.InputEnded:Fire(touch);time=8;repeatSkillHold();assert(#sent==9)
b.InputBegan:Fire(mouse);snapshot.SkillPoints=0;time=9;repeatSkillHold();assert(#sent==10,"server snapshot stops spending when points run out")
print("PASS: real press/hold callbacks, initial delay, cadence, release without duplicate, leave/focus/tab/close stops, points/tier/cap/KO guards, touch identity")
local config={Names={Melee="Melee",Unarmed="Unarmed",Sneak="Sneak",Doctor="Doctor"}}
local palette={Accent="active",Muted="locked"}
local perkRows={};for _,perk in ipairs(Rules.Perks) do perkRows[perk.ID]={} end
local perkPanel={}
local UDim2={fromOffset=function(x,y) return {X=x,Y=y} end}
local function redrawPerks()
ROWS
end
snapshot.Confirmed=false;snapshot.Skills={};snapshot.SkillPoints=0
redrawPerks()
for _,perk in ipairs(Rules.Perks) do
 local row=perkRows[perk.ID]
 assert(row.Visible and not row.Active and row.Text:find(perk.Name,1,true),perk.ID)
 assert(row.Text:find(Presentation.PerkRequirements(perk,config.Names),1,true))
end
assert(perkPanel.CanvasSize.Y==86*#Rules.Perks)
snapshot.Confirmed=true;snapshot.SkillPoints=1
redrawPerks()
assert(perkRows.KhersonMelons.Active and not perkRows.StrongArm.Active)
snapshot.Stats.Strength=7;redrawPerks();assert(perkRows.StrongArm.Active)
snapshot.Perks.StrongArm=1;redrawPerks();assert(not perkRows.StrongArm.Active and perkRows.StrongArm.Visible)
snapshot.Perks={};snapshot.PerkPoints=0;redrawPerks();assert(not perkRows.KhersonMelons.Active)
snapshot.Stats.Attention=7;redrawPerks();assert(not perkRows.Observant.Active)
snapshot.Stats.Attention=8;redrawPerks();assert(perkRows.Observant.Active and perkRows.Observant.Text:find("Free",1,true),"free perk selectable at zero perk points")
snapshot.Perks.Observant=1;redrawPerks();assert(not perkRows.Observant.Active)
print("PASS: all perks visible, locked requirements/ranks, free Attention8 perk enabled at zero points, scroll extent")
'''
receiver=source[source.index('local function receiveState'):source.index('remotes:WaitForChild("State").OnClientEvent:Connect(receiveState)')]
creation_cases='''
local draft,tagDraft
local function setMode(value) mode=value end
local function redraw() redrawPerks() end
RECEIVER
snapshot=nil;mode="Stats"
local fresh=Rules.New();fresh.Skills=Rules.TotalSkills(fresh)
receiveState(fresh)
assert(mode=="Perks" and not snapshot.Confirmed,"first attribute allocation opens directly on Perks")
for _,perk in ipairs(Rules.Perks) do assert(perkRows[perk.ID].Visible and not perkRows[perk.ID].Active) end
mode="Skills";draft.Strength=7;receiveState(fresh)
assert(mode=="Skills" and draft.Strength==7,"creation refresh preserves selected tab and unconfirmed attribute draft")
local confirmed=table.clone(fresh);confirmed.Confirmed=true;confirmed.TagsConfirmed=true;confirmed.TaggedSkills={Melee=true}
receiveState(confirmed);assert(mode=="Skills" and tagDraft.Melee,"confirmation does not force another tab")
mode="Stats";receiveState(confirmed);assert(mode=="Stats","ordinary snapshots preserve the selected tab")
receiveState(fresh);assert(mode=="Perks","a new creation flow opens the catalog again")
print("PASS: first attribute allocation automatically shows every perk before confirmation, later snapshots preserve selected tabs and draft attributes")
'''
parts=['local Rules=(function()\n'+(root/'src/shared/ProgressionRules.luau').read_text()+'\nend)()',
 'local Presentation=(function()\n'+(root/'src/shared/ProgressionPresentation.luau').read_text()+'\nend)()',setup,hold,cases.replace('ROWS',rows),creation_cases.replace('RECEIVER',receiver)]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'hold.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
