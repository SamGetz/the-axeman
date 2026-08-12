# Procedural log exterior placeholders

These 41 images are generated stand-in art for the 21 terrestrial species that
previously depended on `SpeciesDef.bark_tint`. They are deliberately stored under
`wood_placeholders/`, and every affected species also sets
`exterior_textures_placeholder = true` in `species_table.tres`.

- 20 species have a placeholder bark and authored-end texture.
- Balsam Fir keeps its existing bespoke bark and has a placeholder end only.
- Existing Eastern White Pine, Norway Spruce, Paper Birch, and Pedunculate Oak
  exterior art is preserved.
- Fresh runtime slice faces are not part of this set and keep the existing
  `inside_tex` / `inside_tint` strategy.

Generation mode: ImageGen, image-to-image style guidance. Bark used the existing
oak bark as a style-only reference; birches additionally used the existing birch
bark style. Authored ends used the existing oak end as a style-only reference.

Shared bark prompt brief: seamless square diffuse albedo, flat orthographic
surface, species-specific bark structure, cozy hand-painted storybook treatment,
broad low-frequency features, no baked directional lighting, object, background,
foliage, text, or watermark.

Shared end prompt brief: one centered orthographic sawn cross-section filling the
square, species-specific wood colour and ring/grain character, thin matching bark
rim, flat diffuse light, non-repeating, no perspective, cylinder, damage, scene,
text, or watermark.

These are not final botanical or production textures. Replace paths species by
species and clear `exterior_textures_placeholder` when bespoke art lands.
