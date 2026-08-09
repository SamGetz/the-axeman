# Generated production-candidate asset manifest

All files in this directory are replaceable AI-generated production candidates,
not Sam-authored final art. Source originals remain in Codex's generated-image
store. Every candidate was inspected at full size. The original campaign set
received a targeted correction pass; the tutorial portraits passed their first
generation at both full size and live 132-pixel UI presentation.

| Project file | Purpose / integration | Final prompt summary | Source mode | Inspection and correction |
|---|---|---|---|---|
| `ui/supplier_atlas_background_candidate.png` | Low-contrast native Supplier Atlas background | Hand-painted cream world map, forest-green source continents and rust freight routes, no text | Image generation, then referenced-image edit | Removed small buildings/most tree clutter and lightened the central 55% for overlaid controls. Selected corrected result. |
| `alien/resonant_spiralwood_bark_candidate.png` | Tileable Spiralwood bark and cut-surface candidate | Blue-grey layered spiral bark with sparse cyan-green luminous seams | Image generation, then referenced-image edit | Removed large whirlpool focal points and reduced luminous coverage for repeatable tiling and readable weak-band VFX. Selected corrected result. |
| `alien/tideglass_timber_surface_candidate.png` | Tileable Tideglass bark/cut-surface candidate | Smoky-blue timber fibers with pale teal mineral ribbons | Image generation, then referenced-image edit | Removed eye-like knots and water-wave reading; emphasized long wood fibers and sparse mineral seams. Selected corrected result. |
| `alien/cinderheart_bark_candidate.png` | Tileable Cinderheart bark/cut-surface candidate | Charcoal/umber bark with bounded ember fibers in scars | Image generation, then referenced-image edit | Halved glow coverage, broke regular vertical seams into short scar segments and lowered peak orange. Selected corrected result. |
| `portraits/instrument_maker_customer_candidate.png` | Joiner's Workshop customer card portrait | Older regional instrument maker, green work jacket, wood calipers, warm gouache workshop | Image generation, then referenced-image edit | Tightened crop, enlarged face, simplified background and increased hair separation for 64–128 px UI use. Selected corrected result. |
| `ui/earth_master_headline_candidate.png` | Six-second Earth Master campaign-closure presentation behind native headline text | Headquarters celebration and mounted Lignum Vitae cross-section with blank cream headline band | Image generation, then referenced-image edit | Replaced an implausibly giant disc with a trophy-scale mounted cross-section and clarified the completed yard. Selected corrected result. |
| `signage/mission_control_emblem_candidate.png` | Mission Control in-world sign behind native/geometry-authored yard presentation | Pine tree, orbital arc and star in forest green, cream, rust and brass; no text | Image generation, then referenced-image edit | Flattened bevel/shadow, simplified the rim and increased negative space for 64 px readability. Selected corrected result. |
| `tutorial/rowan_pike_candidate.png` | Opening tutorial portrait | Friendly weathered yard keeper in forest-green canvas jacket, safe axe haft, warm dawn timber yard, hand-painted gouache, no text | Built-in image generation | Accepted first generation after full-size inspection and live 132 px crop review; face, silhouette and hand remain readable. |
| `tutorial/ada_gearhart_candidate.png` | Shop, skills and automation tutorial portrait | Friendly millwright in rust work shirt and green apron, brass pencil, warm workshop, hand-painted gouache, no text | Built-in image generation | Accepted first generation after full-size inspection and live Shop-overlay review; clear separation from Rowan and readable tools. |
| `tutorial/nova_quill_candidate.png` | Atlas and launch tutorial portrait | Calm route navigator in navy-green dispatch coat and ochre scarf, map office at twilight, hand-painted gouache, no text | Built-in image generation | Accepted first generation after full-size inspection and live Atlas-focus review; grounded logistics read without prematurely advertising science-fiction content. |

## Validation status

- All three alien surfaces are square opaque PNGs and are assigned through typed
  `AlienWoodTraitDef` resource paths. They use the existing runtime material,
  tangent and MeshSlicer paths rather than a new shader contract.
- The map, portrait, headline and emblem are opaque; no chroma-key or transparent
  import dependency is used.
- `core/tools/campaign_visual_shot.tscn` rendered each alien specimen fresh,
  visibly struck and cut at 1280×720 under the Compatibility renderer. The three
  candidates remain clearly separated at gameplay distance, wrap without a
  dominant seam, retain readable cut faces and leave the native weak-band/scar
  cues visible.
- The same harness inspected the map behind live controls, the Earth Master
  panel behind native headline text, the launch programme and orbital company.
- The Supplier Atlas dock icon is a separately authored native SVG in
  `assets/ui/supplier_atlas_icon.svg`; generated raster art does not replace the
  existing vector icon system.
- Early ledger, handcart, thermos, splitter, craft-grade, active-delivery and
  delivery-stamp placeholders are deliberately code-native SVGs under
  `assets/ui/placeholders/`, not image-generation outputs. They match the current
  vector UI system and remain tagged for final model/UI replacement.
