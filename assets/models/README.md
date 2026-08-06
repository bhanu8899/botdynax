# 3D model

`botdynax_scene.glb` — BotDyNax's own robot + dock model, generated
procedurally by `build_model.mjs.txt` (rename to .mjs and run with
`@gltf-transform/core` + `@gltf-transform/functions` installed).

Built from scratch because the previously-sourced Sketchfab asset was an
exterior *surface shell*: the whole robot chassis was a single
65k-vertex mesh and the whole dock tower a single 59k-vertex mesh
(verified by dumping every node's bounding box). Nothing was separable,
so spinning brushes, driving wheels and per-component fault highlighting
were all impossible on it.

Every functional part here is its own node with its own material:
  Body, TrimRing, Lidar, LidarRing, Bumper, RobotLogo, DustBin,
  WheelLeft/Right, SideBrushLeft, MainBrush, MopPadLeft/Right,
  MopMarkerLeft/Right, DockBase, DockTower, ContactLeft/Right,
  CleanWaterTank, SewageTank, DustBag, DockLogo

Baked animation clips (model-viewer plays one at a time, so each clip
carries every channel that state needs):
  idle, undocking, cleaning, docking, charging, inspect_underside

Fault-highlightable materials, each mapped to a `total_error` code
empirically confirmed on the real W300:
  mop_pad (21) · dust_bin (46) · dust_bag (18)
  clean_tank (24) · sewage_tank (25)

`MopMarkerLeft/Right` share the `mop_pad` material so a mop fault shows
on the top shell immediately, rather than only after the
`inspect_underside` flip reveals the actual pads.

Logo is a real texture-mapped decal baked into the geometry (robot top
shell + dock front face), not a UI overlay.
