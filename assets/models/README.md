# 3D robot models

Two files, both committed to the repo:

- `robot_vacuum.glb` — the original download, contains both the dock and
  the robot together. Shown while the robot is at/approaching the dock
  (`returningToDock`, `docked`, `charging`).
- `robot_only.glb` — derived from the file above by clustering every
  mesh's real world-space position (not a guess) and keeping only the
  42 nodes belonging to the robot, recentered to the origin. Shown for
  every other activity, so the dock disappears once the robot has left it.

Source: "Robot vacuum Cleaner Rob-vac" by darkfrei on Sketchfab
(https://sketchfab.com/3d-models/robot-vacuum-cleaner-rob-vac-7d904c05d4204d19a2940d9d6f21ef8d),
licensed CC-BY 4.0 — attribution to darkfrei is required and is included
in the app's Settings > Credits screen.

To regenerate `robot_only.glb` if `robot_vacuum.glb` is ever replaced,
see the node-clustering + `@gltf-transform/core` extraction approach
used originally (world-space X position splits cleanly into two
clusters: dock nodes cluster below x=0.3, robot nodes above it, in the
original file's local coordinate space).
