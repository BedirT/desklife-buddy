# 09 — Competitor and Product-Pattern Audit

## 1. Purpose

This audit identifies category patterns worth adopting, patterns requiring evidence qualification, and openings for differentiation. It does not treat competitor marketing as health evidence.

## 2. LookAway

Official materials emphasize native macOS design, smart scheduling, heads-up notices, break screens, idle awareness, app/context handling, planned breaks, and Focus-related behaviour [S073].

### Strong patterns

- polished native interaction;
- advance notice before interruption;
- snooze and user control;
- idle awareness to avoid unnecessary prompts;
- full-screen break that feels intentional;
- context integrations;
- simple value proposition.

### Risks/gaps to avoid

- category users may interpret timers as medical prescriptions even when copy is neutral;
- “smart” can imply sensing accuracy beyond what the Mac can know;
- posture/blink/camera expansion would create privacy and validation burden;
- full-screen treatment can become coercive if dismissal is obscured.

### Differentiation opportunity

- explicit evidence strength and uncertainty;
- separate visual and movement clocks;
- accessible-equivalent movement;
- standing distinct from movement;
- no posture/blue-light mythology;
- auditable privacy semantics.

## 3. Time Out

Time Out offers mature customization, normal and micro breaks, natural-break handling, activity awareness, and flexible actions [S074].

### Strong patterns

- long-lived configurable architecture;
- multiple break types;
- natural-break concept;
- advanced schedules for power users;
- user control over appearance/actions.

### Risks/gaps

- extensive settings can overwhelm onboarding;
- “natural break” must not become false movement certification;
- power-user flexibility can obscure evidence-backed defaults.

### Adopt

Use progressive disclosure: strong defaults first, advanced settings later.

## 4. Stretchly

Stretchly is an open-source, cross-platform break-reminder product with configurable schedules, postpone/skip, idle handling, and do-not-disturb/app behaviours [S075].

### Strong patterns

- transparency through open source;
- cross-platform learnings;
- simple break suggestions;
- explicit postpone/skip;
- active community/issue history useful for edge-case research.

### Risks/gaps

- generic exercise suggestions can vary in quality;
- cross-platform abstraction may sacrifice native Mac behaviour;
- fixed messages may not capture accessibility or claims nuance.

### Adopt

Versioned, reviewable content and clear skip semantics. Consider publishing the protocol engine or evidence ledger even if the full app is not open source.

## 5. BreakTimer

BreakTimer emphasizes a simple customizable schedule, working hours, notifications, and custom messages [S076].

### Strong patterns

- low cognitive load;
- easy schedule customization;
- working-hour boundaries;
- clear break/reminder category.

### Risks/gaps

- simplicity can become a rigid clock if context adaptation is weak;
- custom messages can allow unsafe medical claims if unrestricted.

### Adopt

Keep the initial setup simple and treat custom content as plain reminder text with safety/claim warnings.

## 6. Apple Watch stand reminders

Apple’s stand reminders are a familiar behaviour model, but the desktop product should not duplicate or contradict them. Standing for an hour is not the same as a five-minute movement opportunity, and not all users own or can use a Watch.

### Product response

- explain the difference between position change and active movement;
- future Watch integration should reduce redundant prompts;
- no score advantage for Watch users;
- absence of Watch data is unknown, not noncompliance.

## 7. Category anti-patterns

### Fixed-rule authority

“Experts say everyone must do exactly X” hides uncertainty and reduces trust.

### Posture policing

Camera or angle-based “bad posture” alerts oversimplify pain and create surveillance.

### Blue-light fear

Retinal-damage language is not evidence-aligned [S018–S022].

### Forced lockout

Can conflict with urgent tasks, disability, presentations, safety, and user autonomy.

### Walking-only wellness

Excludes users who move differently.

### Fake completion

Idle or standing silently counted as movement undermines truthfulness.

### Health score

Combining break count, posture, water, and focus into one number has no validated weighting.

### Streak punishment

All-or-nothing streaks create shame and gaming rather than sustainable routines.

### Permission-first onboarding

Requesting Calendar, notifications, camera, Accessibility, or Screen Recording before explaining value creates distrust.

### AI exercise generation

Unreviewed dynamic movement content introduces safety and consistency risk.

## 8. Recommended differentiation

1. **Evidence transparency:** every core default has a short “why” and source mapping.
2. **Two-clock truthfulness:** visual recovery and movement remain separate.
3. **Opportunity windows:** context-aware timing without pretending to read the user’s mind.
4. **Accessibility parity:** walking, wheeling, and seated movement are equal-status.
5. **No posture score:** variation and fit instead.
6. **No blue-light marketing:** explicit evidence-aligned stance.
7. **Local-first architecture:** no account required.
8. **Claims compiler:** design/copy/events all follow one machine-readable register.
9. **Versioned break content:** reviewed and source-linked.
10. **Non-punitive weekly rhythm:** patterns without a fabricated health grade.

## 9. Feature priority map

| Feature pattern | Adopt | Modify | Reject |
|---|:---:|:---:|:---:|
| Menu-bar utility | ✓ |  |  |
| Heads-up before overlay | ✓ |  |  |
| Full-screen break |  | ✓ always dismissible/accessibility-first |  |
| Idle awareness |  | ✓ reset burden, not verify movement |  |
| Calendar/Focus integration |  | ✓ optional, minimized |  |
| Custom schedules | ✓ | evidence explanation |  |
| Natural break credit |  | ✓ use careful semantics |  |
| Camera posture/blink |  | future separate review | MVP |
| Blue-light protection |  |  | ✓ |
| Posture score |  |  | ✓ |
| Employer compliance dashboard |  |  | ✓ |
| Forced lockout |  |  | ✓ |
| Hydration quota |  | user-defined only | default |
| Weekly summary |  | ✓ no score/streak shame |  |
