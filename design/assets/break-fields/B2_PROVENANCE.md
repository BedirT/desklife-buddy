# B2 interior-valley production provenance

## Status and rights

- Owner-selected family: B2 interior-valley, selected 2026-08-28.
- Source direction: `exec-d7250cb1-179a-4ce7-8752-f3f00759e07b.png`.
- Tool mode: built-in image generation, using the selected B2 image as a style and composition
  reference rather than as an edit target.
- Rights status: generated for this private product through the available image-generation tool.
  No third-party artwork or owner-supplied restricted asset was imported.
- The generated sources are opaque static PNGs. They contain no text, UI, icons, people, or
  animation. No motion runtime or `.motion.json` manifest is required.

## Source and delivery inventory

| Semantic field | Retained generated source | Source dimensions | Source SHA-256 | App delivery resource | Delivery SHA-256 |
|---|---|---:|---|---|---|
| Visual reset | `sources/b2-visual-reset-source.png` | 1536 x 1024 | `8ac2219ff336b18402f72aca9d4edc3952feed68adf063bb023df38ce5a84be6` | `Packages/Features/Sources/BreakPresentation/Resources/Fields/b2-visual-reset.png` | `3e2d1c91705fd7feb203ddb4f7a049b357c662d565948cf48611b60f2d145801` |
| Walk or wheel | `sources/b2-movement-walk-or-wheel-source.png` | 1586 x 992 | `8a119c5f34dfc0148a6a262cab2d592195daf64103f9b303e89e707d15456c4e` | `Packages/Features/Sources/BreakPresentation/Resources/Fields/b2-movement-walk-or-wheel.png` | `3cce8dd877a92c0ff2b19659befa830c1ab92ce034e8c94640868ebba160ed2f` |
| Small space | `sources/b2-movement-small-space-source.png` | 1536 x 1024 | `8bb284b20b3d4367d83f7174ef9e7ac2cfdc1204ab9838b8b0f6b8d535d401ab` | `Packages/Features/Sources/BreakPresentation/Resources/Fields/b2-movement-small-space.png` | `b6d4df5448fb3d1ec3779a7bb47f4d33fb29a7aafaa788876369385633bc3f1e` |
| Seated | `sources/b2-movement-seated-source.png` | 1536 x 1024 | `f90b28aa906e64385e76426e209e65bfd77afef9f7c41f1d1697c001433082bc` | `Packages/Features/Sources/BreakPresentation/Resources/Fields/b2-movement-seated.png` | `9a6a2a8767cc90845a2065f15372f512c102c8c71dde5f37d1608ad04973d1dc` |

The built-in generator returned sources below 2880 x 1800. The originals above are retained as
the generated masters. Delivery resources are explicitly derived, not represented as freshly
generated 2880 x 1800 masters: Visual Reset, Small Space, and Seated use a centered 1536 x 960
8:5 crop; Walk or Wheel uses a centered 1586 x 991 crop. Each crop is resampled to the app's
2880 x 1800 delivery size with macOS `sips`. All four delivery files remain opaque RGB PNGs.

## Appearance derivation

`BreakFieldView` applies the variants without duplicating raster files. Light and dark preserve
the same composition while presenting it at visibly different hours, as required by D-016:

- light: +0.16 brightness, 1.08 saturation, 0.96 contrast, and one
  `dsStaticDesktopScrim` layer, an effective 35% black veil;
- dark: +0.08 brightness, 0.98 saturation, 1.02 contrast, and one 35% veil;
- Increase Contrast: two layers plus 1.12 image contrast;
- Reduce Transparency: two layers plus 0.90 saturation;
- Reduce Motion: unchanged static image; these resources never animate;
- app Static: `BreakStaticField` uses `DSStaticDesktopField` at the selected brightness and loads
  no image.

The owner-reviewed single veil keeps the selected artwork legible as imagery rather than reducing
it to a nearly black field. The generated masters retain dedicated low-detail text-safe zones;
Increase Contrast and Reduce Transparency add the second veil where stronger separation is needed.

## Presentation motion

The raster fields remain static and require no asset motion manifest. The app panel supplies the
accepted presentation motion through `DSMotion`: Standard uses an 800 ms feathered frost dissolve,
a 250 ms content-free hold, and a 1150 ms feathered reveal of the selected field. Instructions and
controls animate independently within the reveal. Reduce Motion uses an 800 ms crossfade. App
Static orders and closes directly, with no field image and no app motion.

## Generation prompts

### Visual Reset

```text
Use case: stylized-concept
Asset type: opaque full-bleed macOS break atmosphere master, Visual Reset variant
Input image: reference only for the B2 curved interior-to-valley architectural language and warm cinematic realism; do not copy any UI, text, controls, icons, or window chrome.
Primary request: create a calm visual-rest field looking from a dim, sculpted plaster interior through one generous organic curved opening into a distant layered valley at quiet blue-gold dawn. Make the scene unmistakably about distance and visual depth: long soft valley layers, a small reflective river far away, cool atmospheric haze, no implied walking path, no furniture suggesting an exercise action.
Composition: exact 3:2 landscape composition intended for 2880x1800; full bleed with no frame. Keep the upper-center and central-left text-safe zones low-detail and consistently dark enough for white interface copy. Keep the horizon aligned near 71% of image height and uninterrupted across the middle; reserve the bottom 18% as an even dark control-safe band. Put the brightest bloom well right of center, below the upper text-safe band, with a broad gentle rolloff and no clipped white sun disk.
Style: refined cinematic architectural visualization, tactile lime plaster, natural landscape, serene, low novelty for frequent repetition, no fantasy spectacle.
Palette: cool charcoal and umber interior, muted blue-gray valley, restrained pale apricot dawn.
Constraints: fully opaque; no people, no silhouettes, no mobility cues, no chairs, no plants, no books, no lamp, no text, no letters, no numbers, no logos, no interface, no buttons, no icons, no progress bar, no window chrome, no watermark. Preserve large calm negative-space bands for UI overlay.
```

The prompt's `3:2` label conflicts with its explicit 2880 x 1800 size. The explicit 8:5 delivery
size is authoritative and the crop above resolves that generator-input error.

### Walk or wheel

```text
Use case: stylized-concept
Asset type: opaque full-bleed macOS break atmosphere master, Movement walk-or-wheel variant
Input image: reference only for the B2 curved interior-to-valley family, tactile plaster, and warm cinematic realism; remove and do not reproduce any UI, text, controls, window chrome, furniture clutter, or people.
Primary request: create a warm movement field looking from a sculpted interior through a wide asymmetric curved threshold toward a valley. A broad, smooth, gently meandering accessible promenade begins in the mid-distance and continues horizontally into the landscape, clearly usable for walking or wheeling without depicting a person or mobility device. The opening should feel like outward momentum and open air, distinct from the Visual Reset vista.
Composition: exact 3:2 landscape intended for 2880x1800; full bleed. Maintain calm low-detail upper-center and central-left text-safe zones dark enough for white UI copy. Align the distant horizon near 71% of image height, with a continuous calm band for progress. Reserve the bottom 18% as an even dark control-safe band. Brightest warm bloom on the right third, away from text, no clipped sun disk.
Style: refined cinematic architectural visualization, organic curved plaster, natural valley, serene and repeatable rather than dramatic.
Palette: dark umber interior, warm sandstone threshold, muted olive and blue-gray valley, restrained amber late-afternoon light.
Constraints: fully opaque; no people, no bodies, no silhouettes, no wheelchairs, no walking aids, no stairs, no steep grade, no text, no letters, no numbers, no logos, no interface, no buttons, no icons, no progress bar, no window chrome, no watermark.
```

### Small space

```text
Use case: stylized-concept
Asset type: opaque full-bleed macOS break atmosphere master, Movement small-space variant
Input image: reference only for the B2 sculpted interior-to-valley family, material warmth, and cinematic realism; do not reproduce its UI, text, controls, icons, window chrome, furniture clutter, or people.
Primary request: create a warm movement field inside a compact curved plaster alcove that opens to a distant valley through a tall narrow organic aperture. The immediate foreground is a clear uncluttered circular floor bay defined by subtle concentric inlaid rings and soft reflected daylight, suggesting comfortable movement within a small footprint without showing any exercise, body, or equipment. Keep the valley visible so it belongs to the same interior-to-valley family, but make the protected circular movement bay the distinctive idea.
Composition: exact 3:2 landscape intended for 2880x1800; full bleed. Keep upper-center and central-left text-safe regions calm, low-detail, and dark enough for white UI copy. Align the distant horizon near 71% of image height and keep that band visually continuous. Reserve the bottom 18% as an even dark control-safe region. Brightest warm light on the right third, no clipped sun disk.
Style: refined cinematic architectural visualization, tactile lime plaster, serene, low novelty and repeatable.
Palette: cocoa and charcoal interior, muted sandstone floor rings, blue-gray valley, restrained amber light.
Constraints: fully opaque; no people, no bodies, no silhouettes, no yoga pose, no exercise equipment, no stairs, no furniture, no text, no letters, no numbers, no logos, no interface, no buttons, no icons, no progress bar, no window chrome, no watermark.
```

### Seated

```text
Use case: stylized-concept
Asset type: opaque full-bleed macOS break atmosphere master, Movement seated variant
Input image: reference only for the B2 curved interior-to-valley family, tactile plaster, and warm cinematic realism; do not reproduce its UI, text, controls, window chrome, books, lamp, plants, or people.
Primary request: create a warm movement field in a broad sculpted interior niche overlooking the same distant valley. A low, generous continuous curved architectural ledge is integrated into the wall on the right, with open floor beside it and no prescribed body position; subtle arcs of reflected light sweep upward across the plaster, suggesting gentle seated mobility and range without depicting a person or exercise. Keep this visibly distinct from the promenade and circular small-space variants.
Composition: exact 3:2 landscape intended for 2880x1800; full bleed. Keep upper-center and central-left text-safe zones calm, low-detail, and dark enough for white interface copy. Align the valley horizon near 71% of image height and preserve a quiet continuous band there. Reserve bottom 18% as an even dark control-safe region. Brightest warm bloom on the right third, no clipped sun disk.
Style: refined cinematic architectural visualization, organic plaster, serene, mobility-neutral, low novelty and repeatable.
Palette: charcoal-brown interior, warm sand ledge, dusty mauve and blue-gray valley, restrained amber edge light.
Constraints: fully opaque; no people, no bodies, no silhouettes, no posture depiction, no conventional chair, no wheelchair, no exercise equipment, no text, no letters, no numbers, no logos, no interface, no buttons, no icons, no progress bar, no window chrome, no watermark.
```
