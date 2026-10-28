"""Exercise real group authority and scoped snapshots with mock player characters."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src/server/Groups.server.luau').read_text().replace('local Literal=require(game:GetService("ReplicatedStorage").Shared.LocalizationRules)', 'local Literal={Protect=function(v) return v end}')
s=re.sub(r'local (Rules|Sight|Journal|Affiliation)=require[^\n]+\n','',s)
setup='''
local messages={}
local Journal={Send=function(p,message) table.insert(messages,{Player=p,Text=message}) end}
local blocked=false
local Sight={Cast=function() if blocked then return {Instance={IsDescendantOf=function() return false end}} end end}
for _,p in ipairs(Players:GetPlayers()) do p:LoadCharacterAsync();p:SetAttribute("TeamID",10) end
'''
cases='''
local folder=ReplicatedStorage:FindFirstChild("GroupRemotes")
local action=folder:FindFirstChild("Action")
local remote=folder:FindFirstChild("State")
local function send(p,command,value) clock+=.3;action.OnServerEvent:Fire(p,command,value) end
local function snapshot(p) for i=#remote.sent,1,-1 do if remote.sent[i].player==p then return remote.sent[i].data end end end
send(a,"Request");assert(#snapshot(a).Members==0 and not snapshot(a).Invite)
b.Character.HumanoidRootPart.Position=Vector3.new(100,0,0)
send(a,"Invite",b.UserId);assert(not snapshot(b).Invite,"distant invite rejected")
b.Character.HumanoidRootPart.Position=Vector3.zero
blocked=true;send(a,"Invite",b.UserId);assert(not snapshot(b).Invite,"wall blocks invitation")
blocked=false
b:SetAttribute("TeamID",20);send(a,"Invite",b.UserId);assert(not snapshot(b).Invite,"foreign faction denied")
b:SetAttribute("TeamID",nil);a:SetAttribute("TeamID",nil);send(a,"Invite",b.UserId);assert(not snapshot(b).Invite,"unaffiliated players denied")
a:SetAttribute("TeamID",10);b:SetAttribute("TeamID",10)
send(a,"Invite",b.UserId)
assert(snapshot(b).Invite.From==a.UserId and not snapshot(c).Invite,"invitation visible only to intended recipient")
send(b,"Reply",true)
assert(a:GetAttribute("GroupID")>0 and a:GetAttribute("GroupID")==b:GetAttribute("GroupID"))
assert(#snapshot(a).Members==2 and #snapshot(c).Members==0,"unrelated players never receive group roster")
send(b,"Invite",c.UserId);assert(not snapshot(c).Invite,"nonleader cannot invite")
send(c,"Kick",a.UserId);assert(a:GetAttribute("GroupID")>0,"outsider cannot kick")
send(a,"Invite",c.UserId);send(c,"Reply",true);assert(#snapshot(a).Members==3)
send(a,"Invite",d.UserId)
Players.PlayerRemoving:Fire(a);a.Parent=nil
assert(b:GetAttribute("GroupLeaderID")==b.UserId and not snapshot(d).Invite,"departure transfers leadership and cancels invitations")
send(d,"Reply",true);assert(d:GetAttribute("GroupID")==0)
c:SetAttribute("TeamID",nil);assert(b:GetAttribute("GroupID")==0 and c:GetAttribute("GroupID")==0,"pair dissolves")
print("PASS: actual server range/occlusion validation, consent, private invitations/rosters, leader authority, departure and cleanup")
'''
parts=['local Affiliation=(function()\n'+(root/'src/shared/AffiliationRules.luau').read_text()+'\nend)()',(root/'tests/fixtures/town_mock.luau').read_text(),'local Rules=(function()\n'+(root/'src/shared/GroupRules.luau').read_text()+'\nend)()',setup,s,cases]
with tempfile.TemporaryDirectory() as folder:
 path=Path(folder)/'groups.luau';path.write_text('\n'.join(parts));subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
