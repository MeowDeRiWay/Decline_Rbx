"""Quick examination UI data: perk, KO target and proximity gates."""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/client/PatientExamination.luau').read_text().replace('local Locale=require(script.Parent.LocaleController)','local Locale={Text=function(text) return text end}')
setup='''
Players.LocalPlayer=a
a:LoadCharacterAsync();b:LoadCharacterAsync()
b.Character:SetAttribute("Knockout",true);b.Character:SetAttribute("Sick",80);b.Character:SetAttribute("Poisoned",true)
b.Character:SetAttribute("Food",0);b.Character:SetAttribute("Water",0)
'''
cases='''
assert(not Exam.Text(b),"no perk means no examination")
a:SetAttribute("QuickExamination",true)
local text=Exam.Text(b)
assert(text:find("Sickness: 80%%") and text:find("Poisoning: present",1,true) and text:find("Starvation",1,true) and text:find("Dehydration",1,true))
b.Character.HumanoidRootPart.Position=Vector3.new(4,0,0);assert(not Exam.Text(b),"nearby only")
b.Character.HumanoidRootPart.Position=Vector3.new(3,0,0);assert(Exam.Text(b))
b.Character:SetAttribute("Poisoned",false);assert(Exam.Text(b):find("Poisoning: absent",1,true))
b.Character:SetAttribute("Knockout",false);assert(not Exam.Text(b))
b.Character:SetAttribute("Knockout",true);b.Character:SetAttribute("IsDead",true);assert(not Exam.Text(b))
assert(not Exam.Text(a),"self is not another unconscious patient")
print("PASS: Quick examination perk, nearby KO-only gates and live HP/Sick/poison/starvation/dehydration presentation")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'exam.luau';p.write_text((root/'tests/fixtures/town_mock.luau').read_text()+'\n'+setup+'\nlocal Exam=(function()\n'+source+'\nend)()\n'+cases)
 subprocess.run([sys.argv[1],str(p)],check=True)
