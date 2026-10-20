local P=require("../src/shared/JournalPresentation")
local event={ActorName="Chief",TargetName="Zombie",AttackKind="Ranged",Damage=23.8}
assert(P.Combat(event)=="Chief shot Zombie for 24 HP.")
event.Killed=true
assert(P.Combat(event)=="Chief shot Zombie for 24 HP and killed them.")
event.Killed=false;event.TargetName="Provocateur";event.Knockout=true
assert(P.Combat(event)=="Chief shot Provocateur for 24 HP. Provocateur was knocked unconscious.")
event.Kind="Miss"
assert(P.Combat(event)=="Chief missed Provocateur.")
event.Kind="Dodge"
assert(P.Combat(event)=="Provocateur dodged Chief's attack.")
assert(P.Plain('<font color="#ff0000"><b>Test</b></font> &amp; more')=="Test & more")
print("PASS: integer damage, names/actions, death/knockout outcomes, miss/dodge and plain text")
