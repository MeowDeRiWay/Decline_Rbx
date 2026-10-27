# Unaffiliated character ending

A player with no TownID gets the normal 120-second knockout and can still be
revived by a doctor. When the countdown expires, Finish creates the normal
lootable corpse but does not schedule a respawn. Instead the server sets
OutcastEnd and the client shows a full-screen ending:

THIS IS THE END

You decided you could face this world alone. But the world swallowed you, and
your empty shell is now just another part of its scenery.

Only OK sends the server acknowledgement. The server checks that the player is
actually awaiting this ending and has no living character or town. It removes
the hidden old shell, resets inventory, money, level/XP, attributes, perks,
tagged/manual/passive skills and spawn history, then exposes town selection.
Joining a town creates a fresh character with the normal creation UI and full
initial health. Repeated acknowledgements cannot reset the new character.
The corpse remains separate, retaining its loot and existing cleanup rules.

Town members keep their existing death/respawn behavior. Reviving an outcast
before the deadline prevents the ending. Same-server reconnect preserves the
ending, including when a disconnected unaffiliated body dies before reconnect.
This is in-memory continuity, consistent with the existing character sessions;
it is not cross-server persistent character data.

Rojo maps the new OutcastEnd client/server scripts automatically; no models,
attributes or GUI need to be manually installed in Studio. UI text is English.

Validation: run_outcast_end.py, run_outcast_ui.py, run_progression_service.py,
run_town_service.py, run_player_sessions.py, run_medicine.py,
run_player_corpse_expiry.py and run_how_to_play.py execute actual source against
engine mocks. All-source Luau compilation and Rojo build also pass. Roblox Studio
visual/play verification is still required.

Manual check: leave town, get knocked out, wait two minutes, observe the ending
without respawn; click OK, choose town, confirm a new build. Verify the former
body still contains its loot, and town-member death still respawns as before.
