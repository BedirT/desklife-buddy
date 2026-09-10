# Custom Media Lanes

Read this reference only when a surface may benefit from generated imagery,
custom vector art, 3D production, or authored video and motion.

Image generation is mandatory for every new or redesigned visual surface under
`$owner-led-design`. The other media lanes remain conditional on the problem.

## Ground image generation in the current app

Do not begin a page-level exploration from prose alone when the app already has
visual evidence.

1. Capture the target surface from the running app or its accepted Preview at the
   relevant size and appearance. For a new page, capture the app shell, adjacent
   pages, and any existing surface whose materials or navigation should relate.
2. Inspect every reference image before generation. Write a compact keep, change,
   and remove brief so the generator learns from the product without preserving
   its current mistakes.
3. Pass the local screenshots to Codex image generation through
   `referenced_image_paths`. Include the target dimensions, macOS context, real
   state, and intended hierarchy in the prompt.
4. Generate distinct redesign directions in the full interface context. Use
   targeted edits or another grounded pass to refine the owner's preferred
   direction rather than restarting from an unrelated text-only concept.
5. Preserve the referenced screenshots, prompts, and generated candidates in the
   non-canonical exploration record.

Generated text and controls are not authoritative. Preserve accepted copy and
interaction semantics when the direction is translated into native SwiftUI.

## Pick the lane by the visual problem

| Need | Preferred lane | Avoid |
|---|---|---|
| Ordinary functional icon | SF Symbols or an existing design-system symbol | Generating a bitmap for a standard action |
| Illustration, background, material, metaphor, or art-direction study | Codex image generation | Repeating one composition with minor color or size changes |
| Small branded icon or scale-critical flat mark | Approve the concept visually, then produce or convert to SVG | Shipping a rough traced bitmap or a decorative custom icon with no product value |
| Reusable object with coherent form, camera, lighting, or multiple views | Blender, usually rendered to app-ready raster layers | Adding real-time 3D to the app when a still render communicates the same thing |
| Choreography or atmospheric motion study | Storyboard plus a short generated-video study, including Firefly when the owner chooses to use it | Baking localized copy or controls into video |
| Native interaction or state transition | SwiftUI using `$motion` | Shipping video merely to imitate interface animation |

## Shared brief before generating

Define only what changes the result:

- the asset's job and emotional tone;
- exact on-screen size, crop, and focal area;
- the full interface or desktop context around it;
- light and dark behavior;
- required silhouette, material, palette, and negative constraints;
- whether it repeats often enough that novelty may become fatigue;
- static, Increase Contrast, Reduce Transparency, and Reduce Motion equivalents;
- final production format and whether separated layers are truly needed.

Generate at exploration quality first. Produce a production master only after the
owner selects a direction.

## Codex image generation

Use image generation for the mandatory page-level direction pass as well as
opinion pieces, illustration, atmospheric backgrounds, material studies,
metaphor exploration, and motion keyframes.

- Make alternatives conceptually distinct. Vary metaphor, silhouette,
  composition, spatial rhythm, material, or lighting. A different hue, crop, or
  number of otherwise identical arches does not constitute a new direction.
- Show every viable concept in the actual interface at the intended scale. An
  asset sheet may accompany the context view, but cannot replace it.
- Keep a background when it contributes to the scene. Request transparency only
  for layered compositing, flexible recoloring, or a later vector conversion.
- Do not generate text, controls, or symbols that must remain localized and
  pixel-precise. Keep those native.
- After selection, clean the framing, seams, unintended marks, lighting, and
  edge behavior. Do not ship the first generated output merely because the idea
  is correct.

## SVG conversion with the owner

The owner can manually convert an approved image into SVG. Ask for that step only
after the concept is selected and vector output is genuinely the right runtime
format.

Provide a conversion brief with:

- the exact approved source image and intended UI size;
- artboard and crop bounds;
- which background, shadow, texture, or glow should be removed or retained;
- fill and stroke behavior, including minimum stroke at target size;
- required color groups or separable layers;
- whether the result must support tinting, light/dark variants, or recoloring.

Inspect the returned SVG at target size and in both appearances before integrating
it. Conversion is not proof that the icon or illustration works in context.

## Blender and 3D

Use Blender when coherent volume, material, camera, lighting, repeated angles, or
layered depth is essential to the direction. Prefer a pre-rendered still or small
set of layers for this app unless accepted interaction requires real-time 3D.

1. Approve a 2D concept or shape sheet first when form is still unsettled.
2. Lock camera, target crop, projection, light direction, and material family.
3. Render a contact sheet and at least one full in-context screen before polishing.
4. Use transparent film only when the object must composite over multiple native
   canvases. Otherwise keep the designed scene background.
5. Export production resolution plus a smaller integration proxy. Preserve the
   source file and record render settings and provenance.

## Firefly and generated video

Use generated video for concept proof, transition studies, or authored visual
moments after the start frame, end frame, and timing intent are approved. The
owner has access to Firefly, so prepare a precise generation brief when that lane
is useful rather than pretending the tool was run.

The brief should specify:

- start and end frames;
- exact duration and whether the camera is locked;
- what changes over time and what must remain stationary;
- no baked UI, text, countdown, or controls;
- no flicker, flash, sudden luminance jump, shimmer, or unrequested loop;
- intended frame rate, crop, and resolution;
- a static poster or restrained dissolve for Reduce Motion.

After the owner returns a clip, inspect the entire video, key transition frames,
loop seam if one exists, luminance stability, compression, and fit inside the real
app. A video study may establish the desired feel while the production result is
implemented natively in SwiftUI.

## Provenance and acceptance

Record the generator or authoring tool, prompt or brief, date, source files,
rights status, and modifications for any candidate that advances beyond
exploration. Use `$design-ingest` for returned external assets. Final acceptance
always happens on the in-context result, not the raw asset alone.
