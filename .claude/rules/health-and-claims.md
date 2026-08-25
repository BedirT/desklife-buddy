# Rule: Health semantics and claims

Applies to every user-facing string, label, chart, icon, state name, and marketing surface.

Authority: `research/health/08_CLAIMS_SAFETY_REGULATORY_REGISTER.md`, then
`research/health/03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` §12, then
`research/health/machine-readable/claims_register.csv`.

## 1. Intended purpose (must stay constant everywhere)

> The app supports general wellness by reminding adults to take optional visual and movement
> breaks during computer use, offering adaptable break activities, and helping users reflect
> on their work-break routine.

It does not diagnose, prevent, monitor, predict, treat, or mitigate any disease, disorder,
injury, or condition. Onboarding, in-app copy, screenshots, settings, help, and the weekly
view must all be consistent with this sentence.

## 2. Claim classes

| Class | Meaning | Design action |
|---|---|---|
| **A — Factual product claim** | True statements about what the software does | Usable; must actually be true of the design |
| **B — Qualified wellness claim** | Direction-level, hedged ("may", "some people") | Usable with the hedge intact; never strengthen it |
| **C — Validation required** | Outcome/comparative claims | **Do not put in the UI.** Not before a product-specific study |
| **D — Prohibited** | Medical/disease/measurement claims | Never, in any surface, in any tone |

## 3. Non-negotiable terminology

| Say | Never say |
|---|---|
| Estimated active computer use `[C033]` | Sitting time · screen time · sedentary time · you have been sitting `[C013]` |
| Visual reset · a short break from near focus `[C004]` | Eye protection · prevent eye damage · CVS detected `[C007]` |
| Movement opportunity · break up a long computer-use run `[C010]` | Undo sitting damage `[C015]` · lowers blood sugar `[C014]` |
| Position change | Standing goal · stand goal failed `[C048]` |
| Started · shortened · deferred · skipped · you reported | Completed successfully · movement verified `[C034]` · eye strain reduced `[C036]` |
| Two minutes is a useful quick option `[C012]` | Two minutes is equivalent to five |
| Try a different comfortable position `[C020]` | Bad posture `[C022]` · correct your spine `[C023]` |
| Move in a way that works for you `[C047]` | Get up and walk (as the only option) |
| Not a good moment? Snooze or skip `[C037]` | You failed your break `[C038]` · streak lost |
| (nothing — do not build one) | Your wellness score is 82 `[C039]` |

## 4. Prohibited-wording scanner

Flag every occurrence of these for manual review before any string ships
(seed list, `08 §12`):

```
diagnose, detect condition, prevent, treat, cure, mitigate, damage, risk reduction,
blood sugar, blood pressure, perfect posture, bad posture, correct spine, slouch,
retinal, blue light, medical grade, clinically proven, doctor recommended,
calorie, metabolic boost, anxiety treatment, insomnia treatment, verified movement,
sitting detected, compliance, noncompliant, failure, punishment, streak, score
```

A flag is not an automatic ban — it requires context review, and the review outcome goes in
`design/COPY_INVENTORY.md`.

## 5. Event vocabulary the UI may reflect

Only these distinctions exist. Never merge them into "healthy break achieved" `[03 §10]`:

`promptPresented` · `breakStarted` · `timerFinished` · `userDeclaredCompleted` ·
`userDeclaredAlreadyMoved` · `positionChanged` · `snoozed` · `skipped` · `notAppropriate` ·
`likelyNaturalInterruption`

The weekly view may count and pattern these. It may not grade them.

## 6. Break content rules

Movement content comes from `research/health/04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md`.

- Never invent a movement card. Use `V01–V05`, `M01–M05`, `L01–L06`, `P01–P04`, `B01–B02`.
- Tier C content (loaded resistance, deep squats, floor work, neck circles, ballistic
  movement, breath holds) is out of scope entirely.
- Every card needs: plain title · one-sentence non-treatment purpose · 2–3 instructions ·
  an **equal-status** seated/low-balance alternative · a stop/skip sentence · duration.
- `L01 Easy walk` is the preferred default and should surface more often than decorative
  stretch routines.
- Safety footer text is fixed; do not paraphrase it into something friendlier.
- Red-flag/urgent-symptom copy belongs on a dedicated safety page, **not** on routine breaks.

## 7. Evidence transparency

- Concise "Why this?" explanations belong in Settings and Help.
- Citations must never clutter the break overlay or the heads-up.
- The explanation must include the uncertainty, not just the recommendation — e.g. that
  20-20-20 is memorable rather than uniquely proven `[S014]`.

## 8. Before finishing any copy work

Run `.claude/skills/claims-review/`. Every health-adjacent string must resolve to a row in
`claims_register.csv` or an explicit, logged rationale in `design/COPY_INVENTORY.md`.
