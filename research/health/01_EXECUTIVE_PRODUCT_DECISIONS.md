# 01 — Executive Product Decisions

## 1. Product definition

Build a native macOS application that helps adults manage **active computer-use exposure** through:

- short visual resets;
- real movement opportunities;
- optional position changes;
- lightweight workstation guidance;
- context-aware suppression;
- accessible alternatives;
- private, non-punitive reflection.

The product is not primarily an eye-care app, exercise prescription, posture monitor, productivity timer, hydration tracker, medical symptom manager, or employer-surveillance tool.

Its most defensible promise is:

> A private, research-informed way to remember visual and movement breaks without fighting your workflow.

## 2. Decision matrix

| Product question | Decision | Evidence status | Rationale |
|---|---|---:|---|
| Primary behaviour | Interrupt long runs of active computer use with visual recovery and movement | A/B | Supported across activity, microbreak, and eye-strain evidence [S001–S010, S012–S017] |
| Visual cadence | Opportunity around 20–30 minutes; target about 25 | D | 20-20-20 is memorable and low risk, but no unique optimum is established [S014] |
| Movement cadence | Five-minute opportunity centered around about 60 minutes | B/D | Activity breaks are beneficial acutely; 2026 pragmatic evidence supports hourly feasibility [S003–S006] |
| High-frequency mode | Five minutes every 30 minutes, optional and transparently described | B | Strong acute dose in a tiny trial; high burden and no long-term superiority [S004] |
| Quick fallback | Two minutes is valid | D | Supports adherence and the principle that some movement is better than none [S001, S002] |
| Preferred activity | Easy walking or equivalent active movement | A/B | Walking shows the strongest average acute effect and is simple [S003, S005] |
| Standing | Position variation, not automatic movement completion | A/B | Standing reduces sitting; health-outcome evidence is uncertain and it is less active than walking [S011, S034] |
| Visual content | Distant target, relaxed near focus, comfortable complete blinks | B/D | Direction is plausible and low risk; exact sequence is heuristic [S012–S017] |
| Posture | Promote comfort, fit, and variation; no posture score | A | No universal ideal posture; intervention evidence is mixed [S023, S024, S028] |
| Workstation advice | One-time adjustable setup guide, not recurrent policing | A/B | Practical guidance is useful, but prevention claims are not supported [S023, S028–S032] |
| Strength content | Optional library, not core or treatment | B/C | Can help symptomatic workers; not shown as universal prevention [S025–S027] |
| Breathing | Optional calm/reset exercise | B/C | Modest evidence with heterogeneity; no anxiety-treatment claim [S039, S040] |
| Sleep | Optional shutdown/wind-down module | B/C | Adult evidence is nuanced and largely observational [S041–S043] |
| Hydration | Off by default; user-defined only | E/D | Universal quota unsupported; overconsumption can be harmful [S047, S048] |
| Blue light | No damage/protection narrative | A/E | Filtering lenses show little/no short-term eye-strain benefit and screen retinal-damage claims are unsupported [S018–S022] |
| Camera | Exclude from MVP | D/X | Privacy, accuracy, fairness, and claims burden exceed current value |
| Activity sensing | Minimal input-idle proxy; never content capture | D | Feasible on macOS but measures interaction timing only [S065] |
| Calendar | Optional busy/free suppression; discard event content | D | Useful but sensitive and permission-heavy [S070] |
| Focus | User-configured Focus Filter or in-app mode | D | Public API supports configured behaviour, not silent universal Focus reading [S068] |
| Meeting/media detection | Best effort only; limitations disclosed | D | No reliable universal public signal covers all meetings and presentations |
| Break surface | Prominent overlay, always dismissible | D | Salient without coercion |
| Lockout | Never required in default product | D | Autonomy, accessibility, and safety outweigh speculative adherence gains |
| Gamification | Weekly rhythm; no punitive streak or health score | D | Avoid shame and false precision |
| Symptom tracking | Optional, lightweight, separate from core | C/D | Possible personalization value but sensitive-data and pseudo-medical risk |
| Accessibility | First-class release requirement | A | Standards-aligned and ethically necessary [S045, S046, S080] |
| Migraine mode | Static, dim, no pulse/flash, reduced motion | A/B | Light/motion can exacerbate symptoms for some users [S044–S046] |
| Account | Not required | A/D | Minimizes privacy burden and failure points |
| Analytics | Explicit opt-in; coarse events only | D | Learning should not require surveillance |
| Employer features | Exclude from initial scope | D | Avoid coercion, discrimination, and surveillance incentives |
| Medical positioning | General wellness only | A | Claims and intended purpose determine regulatory risk [S054–S058] |

## 3. Rejected assumptions

### 3.1 “20-20-20 is scientifically optimal”

Rejected. A small study found symptom improvement while reminders were active, but no objective dry-eye sign change and poor persistence after reminders stopped [S014]. Use the concept, not “clinically proven 20-20-20” marketing.

### 3.2 “Five minutes every 30 minutes must be the default”

Rejected as universal. Acute evidence is promising but based partly on tiny laboratory studies [S004]. A large short pragmatic intervention suggested hourly breaks had the best feasibility/effectiveness balance [S006]. Make 30-minute movement an optional high-frequency mode.

### 3.3 “Standing completes the health goal”

Rejected. Standing can vary posture and reduce sitting, but walking is more active and better supported for acute metabolic effects [S003, S011]. Track “changed position” separately from “moved.”

### 3.4 “Posture correction prevents pain”

Rejected. There is no established universal posture target, and workstation evidence is mixed [S023, S024]. Do not show red/green posture ratings, skeleton overlays, or “fix your slouch” copy.

### 3.5 “Blue light is the main screen-health problem”

Rejected. Normal consumer-screen blue light has not been shown to damage eyes, and blue-light filtering lenses probably provide little or no short-term eye-strain benefit [S018–S022]. Focus instead on breaks, readability, glare, comfort, and professional evaluation when symptoms persist.

### 3.6 “The app knows the user has been sitting”

Rejected. A user can type standing, read without input, use voice control, leave for another device, or move while away. The app estimates active computer use; it does not measure posture or activity.

### 3.7 “Idle time proves a healthy break”

Rejected. Idle can mean walking, reading, watching, or using another device. Long idle may reset nuisance timers but cannot be recorded as verified movement.

### 3.8 “More forceful reminders are healthier”

Rejected. No evidence establishes that coercive lockout improves long-term health, and it can disrupt urgent work, disability workflows, communication, and trust.

### 3.9 “Every wellness feature belongs in one app”

Rejected. Hydration quotas, hearing-dose inference, sleep coaching, eye care, posture, breathing, and exercise can turn a focused tool into a pseudo-clinic. Core scope stays narrow.

## 4. Product principles

### Honest specificity

State what is known:

- “63 minutes of estimated active computer use.”
- “You chose a five-minute movement break.”
- “You reported lower eye discomfort this afternoon.”

Never upgrade to:

- “eye strain prevented”;
- “sedentary risk reduced”;
- “blood sugar benefit achieved”;
- “posture corrected.”

### Opportunity, not punishment

The app looks for a reasonable moment, offers a heads-up, permits deferral, and learns which contexts are poor. Skipping is information, not misconduct.

### Movement before standing

When feasible, recommend easy walking or equivalent active movement. Standing remains a useful alternative but a separate category.

### Variation before perfection

Encourage varied position, distance, task, and movement. Avoid frozen setup targets.

### Local before cloud

Core scheduling needs no server or account.

### Accessibility before optimization

The system must work for users who cannot stand, walk, see animation, hear cues, use a mouse, or tolerate a bright overlay.

### Evidence visible, not performative

Provide concise “Why this?” explanations in settings/help, not citation clutter during every break.

## 5. MVP scope

### Include

- menu-bar status and quick actions;
- visual and movement clocks;
- heads-up notice and multi-display overlay;
- start, snooze, skip, “not appropriate,” and “already took a break” actions;
- estimated active-use accumulation;
- long-idle reset without claiming completion;
- working hours and temporary pause;
- user-defined application exclusions;
- manual meeting/presentation mode;
- optional Calendar busy/free integration;
- user-configured Focus Filter;
- accessible break library;
- weekly rhythm summary;
- optional local symptom check-in;
- local export and deletion;
- launch at login;
- light/dark, reduced-motion, high-contrast, VoiceOver, and keyboard support.

### Defer

- iPhone/Watch companion and HealthKit;
- standing-desk or walking-pad control;
- camera and posture/gaze/blink estimation;
- team/employer deployment;
- social features and cloud sync;
- AI-generated movement content;
- condition-specific medical guidance;
- predictive health scoring.

## 6. Success definition

The MVP succeeds over a multi-week pilot when users:

- understand what the app measures and does not measure;
- keep reminders enabled voluntarily;
- take or consciously defer useful opportunities without high annoyance;
- can complete breaks through accessible alternatives;
- report acceptably low focus disruption;
- experience few false meeting/presentation interruptions and can correct them easily;
- understand privacy permissions;
- do not interpret the app as diagnosing or treating a condition;
- find it useful without a camera, cloud account, or HealthKit.

The primary product metric is sustained voluntary use with meaningful opportunities—not raw prompt count or forced compliance.
