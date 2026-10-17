# City house generation

The first generator fills existing YardPlace markers. It does not create roads or place new plots.

## Studio setup

- Put complete house Models in **ServerStorage/CityGeneration/Houses**. Names are arbitrary; each needs **ZHouse=true** and an immediate child **Yard** containing its marker Part.
- Keep **ZNumber** on the outer house. Keep **Floor/Zombie_home=true** inside it for the existing zombie spawner.
- Leave **Workspace/YardPlace** Models with **ForZHouse=true** where houses should appear. Their marker Parts define the target center, level and 20x20 footprint.
- Roads stay in Workspace as Models with **Road=true**. Their names and Part names do not matter.
- Plots must be horizontal. Rotating them around Y is supported. Template Yard axes should align with the house pivot axes; do not tilt the marker.

## Placement

The generator clones the entire house, including its Yard and Floor. The Yard bounding-box center aligns with the YardPlace bounding-box center; the house pivot may be offset from that center.

The front of the house is **positive Z**, the blue pivot arrow. The generator finds the nearest point on road tile bounds and selects the closest of the four plot directions toward that road. House forward does not use LookVector, which points toward negative Z. No Front Part is needed.

Only templates whose rotated Yard footprint fits inside the plot are eligible. For matching 20x20 yards this supports quarter turns without diagonal spill. Oversized or misaligned yards are skipped and reported in Output. Match the marker heights to keep the finished floor at the intended level.

## During Play

- Generated houses appear in **Workspace/GeneratedCityHouses**.
- Source templates remain in ServerStorage. The original plot and cloned Yard marker are invisible and non-collidable; the plot's query/touch are disabled. Wall/floor collision and visibility attributes are preserved. All cloned Parts are anchored.
- The plot has a GeneratedHouse ObjectValue referencing its house. The house has a GenerationSource ObjectValue referencing its plot.
- Repeated generation leaves existing houses intact. It does not duplicate them or refill their loot.
- New/unresolved plots are retried every 5 seconds, allowing delayed template/road loading. Removing a plot also removes its generated house on the next pass.
- Generated Floor models are discovered by the existing zombie-home listener. House-wide ZNumber limits still apply.

Change **src/shared/CityGenerationConfig.luau** for Seed, fitting tolerance or retry interval. The same seed, uniquely named template set and unchanged initial plot layout produce the same initial random house choices. Adding plots or changing templates can change later choices. Stop and restart Play to regenerate the full layout with a new seed.

## Validation

`python tests/run_city_geometry.py /path/to/luau` checks four forward directions, offset Yard alignment, rotated plots, marker height, road-edge selection and rejection of oversized/diagonal yards.

`python tests/run_city_service.py /path/to/luau` exercises template discovery, marker hiding, attribute preservation, repeat calls and removed-plot cleanup with Roblox mocks.

Luau compilation and Rojo build are also checked. These tests do not replace checking the supplied models in Studio Play.
