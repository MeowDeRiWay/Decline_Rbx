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

event.Kind="Hit";event.Knockout=false;event.ActorUserId=1;event.TargetUserId=nil;event.TargetName="Zombie";event.TargetIsCreature=true
assert(P.Combat(event,1)=="You shot zombie for 24 HP.")
assert(P.Combat(event,2)=="Chief shot zombie for 24 HP.")
event.TargetName="Provocateur";event.TargetUserId=2;event.TargetIsCreature=false;event.Knockout=true
assert(P.Combat(event,1)=="You shot Provocateur for 24 HP. Provocateur was knocked unconscious.")
assert(P.Combat(event,2)=="Chief shot you for 24 HP. You were knocked unconscious.")
print("PASS: viewer-specific You narration and lower-case creature names")
