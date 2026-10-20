local Rules=require(script.Parent.ProgressionRules)
local Presentation={}
local attributes={
 Strength="Per point:\n+1 kg carry capacity\n+1 melee damage",
 Endurance="Per point:\n+0.2 running speed\n+5 maximum HP\n+1 second sprint reserve",
 Attention="Per point:\n+2% accuracy\n+0.5 studs view",
 Luck="Per point:\n+3% bonus loot chance\n+1 bonus item per 3 points",
}
function Presentation.Attribute(stat) return attributes[stat] or "" end
local descriptions={
  KnifeMaster=function(rank) return string.format("+%g%% knife attack speed\n+%g%% knife damage",5*rank,5*rank) end,
  KevlarApron=function(rank) return string.format("+%g melee damage absorption",rank) end,
  Automatics=function(rank) return string.format("+%g%% automatic accuracy\n+%g%% critical chance",5*rank,rank) end,
  Pistols=function(rank) return string.format("+%g%% pistol accuracy\n+%g%% critical chance",5*rank,5*rank) end,
  Rifles=function(rank) return string.format("+%g%% rifle accuracy\n+%g%% critical chance",5*rank,2*rank) end,
  MachineGuns=function(rank) return string.format("+%g%% machine gun accuracy\n+%g%% critical chance",5*rank,rank) end,
  Unbeliever=function(rank) return string.format("%g%% chance to turn an incoming critical into a normal hit",9*rank) end,
  Careful=function(rank) return string.format("%g%% chance to preserve weapon condition on a shot",9*rank) end,
  NotSoHeavy=function(rank) return string.format("-%g%% ammunition weight",8*rank) end,
  LikeOnWater=function(rank) return string.format("+%g%% dodge chance against all damage",5*rank) end,
  Bullseye=function(rank) return string.format("+%g%% rifle critical chance",5*rank) end,
  Redhead=function(rank) return string.format("%g%% chance to gain 1 Rags from a shovel kill",7*rank) end,
  GoldenHands=function(rank) return string.format("-%g%% workstation crafting time",4*rank) end,
}
function Presentation.Bonus(id,rank)
 return descriptions[id] and descriptions[id](rank) or ""
end
function Presentation.Talent(state,id,definition)
 local rank=Rules.Rank(state,id)
 local text=string.format("Current · %d / 10\n%s",rank,Presentation.Bonus(id,rank))
 if rank<10 then
  text..=string.format("\n\nNext · %d / 10\n%s",rank+1,Presentation.Bonus(id,rank+1))
  if state.Level<(definition.Level or 1) then text..="\n\nRequires level "..(definition.Level or 1)
  elseif (state.TalentPoints or 0)<1 then text..="\n\nNo talent points"
  else text..="\n\nClick to upgrade · 1 point" end
 else text..="\n\nMax rank" end
 return text
end
return Presentation
