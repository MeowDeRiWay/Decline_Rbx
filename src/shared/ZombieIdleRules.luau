local Rules = {}
local phases = {"Standing","Looking","PauseBeforeWalk","Wandering","PauseAfterWalk"}
local durations = {30,8,10,8,10}
function Rules.New() return {Index=1,Elapsed=0} end
function Rules.Step(state,dt)
 state.Elapsed += dt
 while state.Elapsed >= durations[state.Index] do
  state.Elapsed -= durations[state.Index]
  state.Index = state.Index % #phases+1
 end
 return phases[state.Index],state.Elapsed/durations[state.Index]
end
function Rules.FinishWalk(state)
 if state.Index == 4 then state.Index=5; state.Elapsed=0 end
end
return Rules
