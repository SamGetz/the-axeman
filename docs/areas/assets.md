# Asset and import area guide

Read this only for Maya, FBX, textures, materials, or Godot import work.

- Maya sources live under `maya_working/`; shipped/imported assets live under
  `the-axeman/assets/`. Runtime code must never reference `maya_working/`.
- FBX uses Y-up. Resolve Maya-centimetre/Godot-metre scale once in export/import,
  and freeze transforms/delete history before export.
- `MeshUtils.mesh_from_scene` bakes an imported mesh node's transform. Validate
  the resulting vertex bounds and size by a target height.
- Godot may bind an external `.tres` material beside an FBX when its name matches
  the FBX material slot. A material name cannot prove which texture is bound.
  Run `core/tools/inspect_materials.gd` on every art drop.
- Runtime cut faces use `SpeciesDef.inside_tex` and `inside_normal`, not the
  authored FBX end material. Cut-face textures must tile cleanly.
- Run `species_shot` after new log art or bark tint changes and inspect fresh and
  cut states. Narrow its debug constants only when a full species sweep is not
  needed.
- `.godot/` and generated imports are derived machine-local state. Do not commit
  `.godot/`. Rebuild imports twice on a fresh clone before trusting tests.
- Revisit Git LFS before committing any future individual art file approaching
50 MB; the current repository does not require LFS.
