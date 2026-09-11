# Information Architecture

Derived from `research/health/05_DESIGNER_AGENT_BRIEF.md` §5 and the interruption hierarchy in
`PRODUCT_MODEL.md` §4.

---

## 1. Top-level structure

The app has no "home". It has an ambient presence and five destinations, four of which the
user opens deliberately. The fifth is the optional capability center; it exists even when all
sensing is Off so denial and revocation never remove the person's controls.

```
Menu-bar item  (Level 0, always present)
└── Status menu
    ├── Status region       next visual · next movement · current state
    ├── Start visual reset
    ├── Start movement      ▸ 5 minutes / 2 minutes
    ├── Pause               ▸ 30 min / 1 hour / until a time / until tomorrow / Presenting
    ├── Working hours       (toggle, with the current window as its subtitle)
    ├── ─────────
    ├── Weekly rhythm…      → window
    ├── Sensing & Intelligence… → window (shows Off when unused)
    ├── Settings…           → window (⌘,)
    ├── ─────────
    └── Quit Cadence

Interrupt surfaces (system-initiated, transient — not "places")
├── Heads-up            Level 1
├── Break               Level 2   visual · movement · merged · position · recovery
└── Acknowledgement     Level 3   inline tail of a break

Windows (user-initiated — real places)
├── Weekly rhythm       Level 4
├── Sensing & Intelligence capability status, inspector, stop, correct, effects
├── Settings            9 sections
└── Onboarding          first launch only
```

Rationale for what is *not* here: no dashboard, no history browser, no content library
browser, no "today" view. Each was considered and rejected — see `DECISIONS.md` D-007.

## 2. Status menu

Apple's guidance prefers a menu over a popover for a menu-bar extra. We use a menu with a
compact custom status region at the top rather than a popover mini-app — see `DECISIONS.md`
D-003.

Content, in order:

| Item | Shows | Notes |
|---|---|---|
| Status region | Visual: next in ~11 min · Movement: next in ~34 min · state line | Non-interactive. No ticking seconds. |
| Start visual reset | — | Available always |
| Start movement ▸ | 5 minutes · 2 minutes · Position change | Submenu keeps the top level short |
| Pause ▸ | 30 minutes · 1 hour · Until a time… · Until tomorrow · Presenting… | Checkmark shows the active pause |
| Working hours | Current window as subtitle | Toggle |
| Weekly rhythm… | — | Opens window |
| Sensing & Intelligence… | Active source count or Off | Opens the status/control center; never hidden while a source is active |
| Settings… | ⌘, | Opens window |
| Quit | ⌘Q | — |

When suppressed, the status region's state line explains **why**, in the user's words
(`PRODUCT_MODEL.md` §6), and the resume affordance is present.

## 3. Settings

Nine sections, ordered by how often a real user touches them, matching `[05 §5]` and D-044.

| # | Section | Contains |
|---|---|---|
| 1 | **Schedule** | Profile (Gentle/Balanced/Frequent/High-frequency/Deep-work/Custom) · visual interval & duration · movement interval & duration · heads-up on/off & lead time · working hours · onboarding ramp |
| 2 | **Break content** | Preferred movement (walk-or-equivalent / seated active / mixed / position change) · which activities may appear · 2-minute option visibility · optional breathing content · standing-desk mode · content library browser (read-only) |
| 3 | **Context & exclusions** | Excluded apps · pause behavior · low-friction-moment waiting · presentation mode · idle handling · what happens after suppression |
| 4 | **Accessibility** | Reduced motion / static mode · high contrast · overlay brightness · text-only break mode · timer announcement cadence · keyboard shortcuts · seated-first content · sound (off by default) |
| 5 | **Sensing & Intelligence** | Every optional capability · source state and indicator · session/window scope · Off/Shadow/Suggest/bounded automatic effect · last decision · correction · Stop all sensing |
| 6 | **Privacy & data** | What is stored by record family · raw/derived lifetimes · Strict Local mode · retention (30/90 days, keep nothing) · export · capability delete · delete calibration/rules/history · reset all · analytics opt-in (off) · optional check-ins (off) |
| 7 | **Integrations** | Notifications · Calendar busy times · Focus Filter · Launch at login · Apple companions. Each: current state, what it is for, what it does *not* read, and how to revoke |
| 8 | **Why these defaults?** | Evidence transparency. Visual breaks · movement · standing vs moving · no posture score · no blue-light framing · what each estimate can and cannot know · link to the source library |
| 9 | **Safety & support** | Routine safety text · persistent-symptom guidance · urgent red-flag text · what the app cannot assess · support and feedback |

Progressive disclosure: each section leads with the two or three controls people actually
change, with the rest behind a disclosure. Time Out's failure mode is a settings surface that
overwhelms onboarding `[09 §3]`.

## 4. Weekly rhythm

One window, one scroll, no tabs, no date-range picker in v1.

| Block | Content | Explicitly not |
|---|---|---|
| Header | The week · estimated active computer use total, labeled as an estimate | No headline number in score form |
| Rhythm | Time-of-day pattern of estimated active use across the week | No calendar grid of red misses |
| Longest run | Longest estimated uninterrupted run, and when | No "danger" framing |
| Opportunities | Shown · started · shortened · deferred · skipped — as counts, in neutral color | No percentage-complete, no ring |
| Contexts | Where deferrals clustered (time of day, suppression reason) | No app names |
| Self-report | Optional, only if enabled | Off by default |
| Adjust | "Make the schedule gentler / change the window / exclude an app" | Never framed as a fix for failure |

No score. No streak. No grade. No red. No comparison — to other users, or to last week as
judgment `[03 §14]`.

## 5. Onboarding

Four steps plus a closing step. No permission requests anywhere in it `[03 §13]`.

1. **What this is** — private, research-informed visual and movement breaks.
2. **What it can and cannot know** — the honesty table, compressed to a few lines. This screen
   is the product's thesis; it is not a legal page.
3. **Rhythm** — Gentle / Balanced / Frequent, with plain-language consequences. Balanced
   preselected. "You can change this any time" is true and shown.
4. **How you move** — walk or equivalent / seated active movement / mixed / position changes.
   All four at equal weight, no "limited mobility" framing.
5. **Comfort** — reduced motion, static break, overlay brightness. Prefilled from system
   settings, and says so.
6. **Ready** — starts working immediately. Optional integrations are named here but *not*
   requested; a single line points to Settings.

Target: under 90 seconds, skippable at any point to a working default state.

## 6. Where each concern lives

| Concern | Home | Also surfaced |
|---|---|---|
| Next break | Menu-bar glyph | Status menu |
| Why it's quiet | Status menu state line | Menu-bar glyph variant |
| Why this decision happened | `Why now?` from status/Weekly | Sensing inspector decision chain |
| Take a break now | Status menu | Global shortcut (optional) |
| Change frequency | Settings ▸ Schedule | Weekly ▸ Adjust · post-deferral suggestion |
| Movement preference | Settings ▸ Break content | In-break activity choice |
| Evidence & uncertainty | Settings ▸ Why these defaults? | One quiet link on the break surface |
| Optional sensing | Sensing & Intelligence | Status menu indicator · capability page · Weekly assistant audit |
| Permissions | Capability page or Settings ▸ Integrations | The moment of value, after source/effect preview |
| Safety | Settings ▸ Safety & support | Footer line on movement content |
| Data | Settings ▸ Privacy & data | Capability lifecycle · onboarding step 1 (promise only) |

## 7. Naming

| Concept | UI term | Never |
|---|---|---|
| Visual clock event | **Visual reset** | Eye break · eye care · 20-20-20 |
| Movement clock event | **Movement break** | Exercise · workout · activity goal |
| Sit↔stand transition | **Position change** | Stand goal · stand hour |
| Accumulated signal | **Estimated active computer use** | Screen time · sitting time · focus time |
| Advance notice | **Heads-up** | Alert · warning |
| Level 4 window | **Weekly rhythm** | Dashboard · report · stats · insights |
| Evidence section | **Why these defaults?** | Science · research center |
| Quiet states | **Paused / Quiet** | Snoozed (reserved for a single deferral) · Disabled |
| Scheduling continues, presentation waits | **Held** | Paused · completed |
| Optional capability home | **Sensing & Intelligence** | Surveillance · AI health center |
| Evidence detail | **Sensing inspector** | Body report · diagnosis |
| Decision explanation | **Why now?** | AI insight · health reason |
