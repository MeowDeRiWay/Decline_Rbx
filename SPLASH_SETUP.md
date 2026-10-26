# Opening splash

Rojo creates ReplicatedFirst/SplashImages and preserves its Studio-authored children.
Add StringValue children named Splash01, Splash02, Splash03, etc. Set each Value
to a positive Roblox image asset ID, either digits or rbxassetid://123456789.
Upload generated artwork as an image using Studio Asset Manager first; local PNG
filenames are not Roblox image IDs. Save/publish the place to retain these entries;
they are Studio assets, not automatically committed to Git.

One valid entry is selected uniformly at each client startup. Only that image is
preloaded, with a five-second timeout. The image fades in over0.45s, remains fully
visible for3s, fades to dark over0.45s, then reveals the underlying town menu over
0.35s. It does not wait for city/character readiness and does not replay on respawn.
Empty pools, invalid IDs or failed/timed-out downloads use a DECLINE text splash
with the same timing. No Continue button or loading progress meter remains.

Use landscape16:9 images, preferably1920x1080. Fit preserves the whole image, with
dark margins when the screen aspect differs. Baked-in text is left untouched; no
additional title overlays a valid picture.
