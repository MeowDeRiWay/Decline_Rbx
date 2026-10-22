"""Exercise actual zombie voice playback with minimal Sound/clock mocks."""
from pathlib import Path
import subprocess, sys, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/Services/ZombieAudio.luau').read_text()
prefix='''
local clock=0
local Enum={RollOffMode={LinearSquare="LinearSquare"}}
local os={clock=function() return clock end}
local Random={new=function() return {NextNumber=function(_,a) return a end,NextInteger=function() return 1 end} end}
local debris={}
local game={GetService=function() return {AddItem=function(_,s) table.insert(debris,s) end} end}
local function sound(name)
 local s={Name=name,SoundId="rbxassetid://1",Volume=.17,PlaybackSpeed=.8}
 function s:IsA(c) return c=="Sound" end
 function s:GetAttribute() return nil end
 function s:Destroy() self.Destroyed=true;self.Playing=false end
 function s:Stop() self.Playing=false end
 function s:Play() self.Playing=true end
 function s:Clone() return sound(self.Name) end
 s.Ended={Once=function(_,f) s.finish=f end}
 return s
end
local head={IsA=function(_,c) return c=="BasePart" end}
local templates={sound("ZIdle1"),sound("ZAttack1"),sound("ZDie1")}
for _,s in ipairs(templates) do s.Playing=true;s.PlayOnRemove=true end
local folder={GetChildren=function() return templates end,GetDescendants=function() return templates end}
local model={FindFirstChild=function(_,name) return if name=="Sounds" then folder elseif name=="Head" then head else nil end}
'''
checks='''
Audio.Prepare(model)
for _,s in ipairs(templates) do assert(not s.Playing and not s.PlayOnRemove,"folder templates must never play globally") end
Audio.Update(model);assert(#debris==0)
clock=8;Audio.Update(model);assert(#debris==1)
local idle=debris[1];assert(idle.Parent==head and idle.Volume==.17 and idle.PlaybackSpeed==.8 and idle.Playing)
Audio.Play(model,"Attack");assert(idle.Destroyed and #debris==2)
Audio.Stop(model);assert(debris[2].Destroyed)
Audio.Play(model,"Die");assert(#debris==3)
Audio.Play(model,"Die");clock=100;Audio.Update(model);assert(#debris==3,"death plays only once, no later idle")
debris[3].finish();assert(debris[3].Destroyed)
print("PASS: idle timing, spatial origin, authored mix, interruption, sleep stop, death once and cleanup")
'''
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'audio.luau'
 p.write_text(prefix+'\nlocal Audio=(function()\n'+source+'\nend)()\n'+checks)
 subprocess.run([sys.argv[1],str(p)],check=True)
