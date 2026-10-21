from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
rules=(root/'src/shared/ProgressionRules.luau').read_text()
presentation=(root/'src/shared/ProgressionPresentation.luau').read_text().replace('local Rules=require(script.Parent.ProgressionRules)','')
config=(root/'src/shared/ProgressionConfig.luau').read_text()
cases='''
local state=Rules.New();state.Profession="Hunter";state.Level=1;state.TalentPoints=1
local talent=Config.Professions.Hunter.Talents.Automatics
local text=Presentation.Talent(state,"Automatics",talent)
assert(string.find(text,"Current · 0 / 10",1,true) and string.find(text,"Next · 1 / 10",1,true))
assert(string.find(text,"+5 automatic accuracy",1,true) and string.find(text,"+1% critical chance",1,true))
assert(Rules.Learn(state,"Automatics",talent))
text=Presentation.Talent(state,"Automatics",talent)
assert(string.find(text,"Current · 1 / 10",1,true) and string.find(text,"+10 automatic accuracy",1,true))
assert(string.find(text,"No talent points",1,true))
state.Talents.Automatics=10
assert(not string.find(Presentation.Talent(state,"Automatics",talent),"Next",1,true))
assert(string.find(Presentation.Talent(state,"Automatics",talent),"Max rank",1,true))
assert(string.find(Presentation.Talent(state,"Careful",Config.Professions.Hunter.Talents.Careful),"Requires level 5",1,true))
for profession,definition in pairs(Config.Professions) do
 for id in pairs(definition.Talents) do
  assert(Presentation.Bonus(id,0)~="" and Presentation.Bonus(id,10)~="","all talents need current/next descriptions")
 end
end
for _,id in ipairs({"SurpriseServing","GrandmasMethod","RamsayMethod"}) do
 assert(Config.Professions.Cook.Talents[id]==nil)
 assert(not Rules.Learn(state,id,Config.Professions.Cook.Talents[id]),"removed talents rejected")
end
for _,stat in ipairs(Config.Stats) do
 local text=Presentation.Attribute(stat)
 assert(string.sub(text,1,10)=="Per point:" and not string.find(text,"Maximum",1,true))
end
assert(string.find(Presentation.Attribute("Attention"),"+0.5 studs",1,true))
print("PASS: all current/next talent descriptions, upgrade progression, max/locked/no-point states, compact per-point attributes, removed talents rejected")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'presentation.luau';p.write_text('local Rules=(function()\n'+rules+'\nend)()\nlocal Config=(function()\n'+config+'\nend)()\nlocal Presentation=(function()\n'+presentation+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(p)],check=True)
