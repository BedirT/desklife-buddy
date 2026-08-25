---
name: plan-feature
description: Plan multi-step or multi-session work in a living plan file under docs/plans/ — scope, intake or escalation gaps, checkbox progress, and session continuity. Use for any feature beyond a single-screen change, when the user asks for a plan, AND when resuming — "continue", "pick up where we left off", or any reference to in-flight work.
---

# Plan-first features

The user steers by editing one file; sessions stay disposable because
state lives in the plan and the commits, not the conversation.

1. Write `docs/plans/<yyyy-mm-dd>-<slug>.md` from `docs/plans/TEMPLATE.md`:
   outcome, non-goals, OPEN QUESTIONS, then steps where each step ends at a
   named verification-ladder rung.
   The open-questions section contains only unresolved constitution-level
   escalations. Read docs/preferences.md and product context first. Materially
   incomplete product intent routes once through $grill-me; do not create a
   second approval round for layout, states, copy, ordering, confirmations,
   motion, iconography, naming, or implementation details that the accepted
   context can resolve. Record reversible choices and their proof in the plan's
   decision log.
2. If a real escalation remains, stop with one batched question and a
   recommendation. Otherwise mark the plan executable and continue. A newer
   owner edit still outranks earlier context; record durable answers in
   docs/preferences.md and feature-local answers in the decision log.
3. Execute step by step: tick `- [x]` as each step's rung passes; commit per
   verified step, message referencing the plan
   (`feat: items filter — step 3 of docs/plans/2026-06-12-items-filter.md`).
4. Scope changes mid-flight (new constraint, obsolete step) → update the plan
   file first, flag the edit in your next message, continue.
5. Session degrading, or work spanning days → finish the current step, leave
   the plan updated + committed. The next session resumes from the plan file,
   never from compacted conversation memory.
6. RESUMING existing work (this skill triggers for that too): list
   docs/plans/, open the in-progress plan, verify its claims against reality
   (git log + the step's exit rung) before continuing — checkboxes can lie if
   a session died mid-step. First unchecked step that verifies clean is the
   next move; log any drift you found in the decision log.
