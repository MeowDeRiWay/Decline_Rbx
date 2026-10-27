# How to play

Rojo automatically maps `src/client/HowToPlay.client.luau` and
`src/server/HowToPlay.server.luau`; no manual GUI/model setup is required.

The English guide has a left sidebar: Controls (the default on each opening),
Getting started & builds, Society and Resources. The right pane scrolls only the
selected page. Canvas height is measured from wrapped text at the same logical
width/font size as the displayed label, so the scrollbar covers all paragraphs.
Doctor [4] and keypad 4 are included in the guide and blocked while it is open.

The English guide opens once per login after the splash and mandatory town /
character creation panels. Closing it without checking the box leaves automatic
help enabled. **Don't show on login** persists per Roblox UserId across servers
and devices. The HUD **?** button opens the guide even when automatic help is off;
unchecking the box enables it again for the next login. Death/respawn doesn't
trigger another automatic popup. Other menus must be closed before manual opening.
The game continues while the guide is open; this UI does not pause a multiplayer
server. Movement, sprint, combat, camera orbit and character aiming are blocked
while reading it.

The server exclusively owns `DeclineHelpPreferences_v1`, key `User_<UserId>`.
Only a boolean can be changed by a player, only for their own preference. Writes
are coalesced, retried and flushed on departure/shutdown. Unchanged defaults are
never written, including after load failures. Failure notices appear in the guide;
click the checkbox again to retry a failed save. Preference attributes and HelpOpen
are excluded from the same-server character reconnect snapshot.

DataStore access is required for cross-login persistence. Test in a published
experience; for a separate Studio test experience enable **Enable Studio Access to
API Services** under Security. Without access the guide still works and reports
the load/save error rather than claiming persistence.

Validation: actual source lifecycle mocks in tests/run_how_to_play.py and
run_help_preferences.py; existing camera, splash, reconnect and player-list tests;
all source compiled with luau-compile and Rojo build passed. Visual layout and
live DataStore persistence still need Roblox Studio / published-game verification.

Manual check: join, finish creation, read guide; close with box off and reconnect
(guide returns); check box and wait for save, reconnect (guide stays closed);
open **?**, uncheck, reconnect (guide returns); respawn without a second popup.
