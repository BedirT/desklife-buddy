---
name: claims-review
description: Audit user-facing health, wellness, and data copy for the Cadence macOS utility against the machine-readable claims register. Use whenever new or changed user-facing strings exist, before finishing a screen, and before any handoff. Checks each string against claims_register.csv, the prohibited-wording scanner list, and the estimate-vs-declaration-vs-verification distinction.
---

# Claims review

Every health-adjacent string must be defensible against the research package. This is the
product's differentiator, so treat a claims failure as a correctness bug, not a copy nit.

## Sources of truth

1. `research/health/machine-readable/claims_register.csv` — C001–C050
2. `research/health/08_CLAIMS_SAFETY_REGULATORY_REGISTER.md`
3. `research/health/03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` §12 (copy system)
4. `research/health/04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md` (break content + safety text)
5. `.claude/rules/health-and-claims.md`

## Procedure

### 1. Collect
Gather every user-facing string in scope: labels, buttons, menu items, timers, empty states,
tooltips, notification text, settings descriptions, error text, onboarding, weekly view labels,
VoiceOver strings. **VoiceOver strings count** — they are user-facing copy.

### 2. Mechanical scan
```bash
grep -inE 'diagnos|detect|prevent|treat|cure|mitigat|damage|risk|blood sugar|blood pressure|posture|spine|slouch|retina|blue light|medical|clinical|proven|doctor|calorie|metabol|anxiety|insomnia|verified|sitting|complian|fail|punish|streak|score|perfect|protect' design/COPY_INVENTORY.md
```
Every hit needs an explicit verdict. A hit is not an automatic ban — it is a mandatory review.

### 3. Classify each string
- **A — factual product claim**: is it actually true of the design as specified?
- **B — qualified wellness claim**: is the hedge intact ("may", "can", "some people")? Has
  anyone strengthened it?
- **C — validation required**: it must not be in the UI at all. Flag for removal.
- **D — prohibited**: remove. No rewording rescues a class-D idea.

Map each to a `C###` row where one applies. Where no row applies, write the rationale in
`design/COPY_INVENTORY.md` and note that it may need a new register row.

### 4. Semantic distinctions
For each string, check that it does not collapse:
- estimate → measurement ("estimated active computer use", never "sitting time");
- declaration → verification (user said they moved ≠ movement verified);
- timer completion → health outcome;
- visual reset → movement completion;
- position change → movement;
- idle → break taken.

### 5. Tone
Non-judgmental, second-person-light, no urgency, no praise-for-compliance, no
disappointment-for-skipping. Skipping is information, not misconduct.

### 6. Safety copy
- Routine safety footer present on movement content and worded as the package words it.
- Urgent red-flag copy present on the dedicated safety page and **absent** from routine breaks.
- No triage language anywhere `[C042]`.

### 7. Consistency
The intended-purpose sentence must hold across onboarding, settings, help, weekly view, and
any marketing surface in the repo. Flag drift.

## Output

```
## Claims review — <scope>

| String | Location | Class | Register row | Verdict | Fix |

### Must remove
### Must reword
### Needs a new register row
### Passed with note
```

Update `design/COPY_INVENTORY.md` with the outcome for every string reviewed.
