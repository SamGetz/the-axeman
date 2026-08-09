# Placeholder graphics inventory

This inventory distinguishes complete playable placeholders from final authored
art. Placeholder completion means the player no longer sees a raw “missing art”
label; it does not approve the asset as final production art.

## Generated portrait and campaign candidates

- Tutorial portraits: Rowan Pike, Ada Gearhart and Nova Quill.
- Existing campaign candidates: Supplier Atlas, Earth Master closure, Mission
  Control emblem, instrument-maker portrait and three alien wood surfaces.
- Provenance, final prompts and inspection notes live in
  `the-axeman/assets/generated/MANIFEST.md`.

## Code-native vector placeholders

The following audited gaps now have loadable SVG graphics under
`the-axeman/assets/ui/placeholders/`:

- Supplier Ledger
- Handcart
- Coffee Thermos
- Mechanical Splitter
- Craft grade feedback
- Active delivery chip
- Delivery completion stamp

The four equipment plates are mounted on the existing Compatibility-safe
placeholder geometry. The UI graphics are integrated into their live feedback
controls. Scene metadata uses `placeholder_graphic_integrated_pending_final_*`
so artists can still find every replacement target.

## Still requiring final art

- Final 3D models for the ledger, handcart, thermos, splitter, yard vehicles,
  launch structures, vessel, alien specimen rig and orbital company.
- Final UI skin, typography, motion and audio treatment.
- Final character sheets or animation are not required for the current UI-only
  mentors; their portraits are sufficient for the implemented tutorial.

The current placeholder milestone intentionally does not restore villagers,
staff rosters, explorable forests or tree-felling scenes.
