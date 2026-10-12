local Rules = {}
-- Three kinds of activity; standing occurs twice in the repeating sequence.
local phases = {"Standing","Looking","Standing","Wandering"}
local function duration(state)
 if state.Index == 1 or state.Index == 3 then return state.Random(5,30) end
 return state.Index == 2 and 8 or math.huge
end
local function nextPhase(state)
 state.Index = state.Index % #phases+1
 state.Duration = duration(state)
end
function Rules.New(random)
 local state = {Index=1,Elapsed=0,Random=random or math.random}
 state.Duration = duration(state)
 return state
end
function Rules.Step(state,dt)
 state.Elapsed += dt
 while state.Elapsed >= state.Duration do
  state.Elapsed -= state.Duration
  nextPhase(state)
 end
 return phases[state.Index],state.Elapsed/state.Duration
end
function Rules.FinishWalk(state)
 if state.Index == 4 then
  state.Elapsed = 0
  nextPhase(state)
 end
end
return Rules
