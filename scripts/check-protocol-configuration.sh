#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"
cd "$ROOT"

input="$ROOT/research/health/machine-readable/product_protocol.yaml"
runtime_contract="$ROOT/design/machine-readable/timing_runtime_v2.yaml"
event_schema="$ROOT/research/health/machine-readable/event_schema.json"
generated="$ROOT/App/Protocol/GeneratedProtocolProfiles.swift"
temporary="$(/usr/bin/mktemp -t protocol-profiles).swift"
trap '/bin/rm -f "$temporary"' EXIT

/usr/bin/ruby "$ROOT/scripts/support/generate_protocol_configuration.rb" "$input" "$temporary"
mise_exec swiftformat "$temporary" --config "$ROOT/.swiftformat" --cache ignore >/dev/null

if ! /usr/bin/cmp -s "$temporary" "$generated"; then
  echo "Generated protocol profiles are stale. Run scripts/generate-protocol-configuration.sh." >&2
  /usr/bin/diff -u "$generated" "$temporary" || true
  exit 1
fi

/usr/bin/ruby - "$input" "$runtime_contract" "$event_schema" <<'RUBY'
require "date"
require "json"
require "pathname"
require "yaml"

protocol_path, runtime_path, event_path = ARGV
protocol = YAML.safe_load(File.read(protocol_path), permitted_classes: [Date])
runtime = YAML.safe_load(File.read(runtime_path), permitted_classes: [Date])
event = JSON.parse(File.read(event_path))

def assert(condition, message)
  abort "Protocol contract mismatch: #{message}" unless condition
end

expected_facts = %w[
  promptPresented
  breakStarted
  timerFinished
  userDeclaredCompleted
  userDeclaredAlreadyMoved
  positionChanged
  snoozed
  skipped
  notAppropriate
  likelyNaturalInterruption
]
expected_clocks = %w[visual movement position recovery]
expected_new_presets = %w[calm balanced_v2 frequent_reset adaptive custom_v2]
expected_legacy_profiles = %w[
  gentle
  balanced
  frequent_movement
  research_informed_high_frequency
  custom
]
expected_v2_presets = {
  "calm" => {
    "visual" => [1500, 1800, 1980, 20],
    "movement" => [3600, 4500, 5400, 300, 120],
    "position" => 3600,
  },
  "balanced_v2" => {
    "visual" => [1200, 1500, 1620, 20],
    "movement" => [3000, 3300, 4200, 300, 120],
    "position" => 2700,
  },
  "frequent_reset" => {
    "visual" => [1080, 1200, 1320, 20],
    "movement" => [1800, 2100, 2700, 300, 120],
    "position" => 1800,
  },
}

assert(runtime.dig("meta", "version") == 2.0, "timing runtime version must be 2.0")
assert(runtime.dig("meta", "decision") == "D-033", "timing runtime must cite D-033")
runtime_health_path = Pathname.new(runtime_path).dirname.join(runtime.dig("meta", "health_values")).cleanpath
runtime_fact_path = Pathname.new(runtime_path).dirname.join(runtime.dig("meta", "product_fact_schema")).cleanpath
assert(runtime_health_path == Pathname.new(protocol_path).cleanpath, "runtime health-values pointer drifted")
assert(runtime_fact_path == Pathname.new(event_path).cleanpath, "runtime fact-schema pointer drifted")
assert(
  protocol.dig("meta", "canonical_runtime_contract") ==
    "../../../design/machine-readable/timing_runtime_v2.yaml",
  "product protocol must point to timing_runtime_v2.yaml",
)
assert(
  protocol.fetch("preset_contract_v2").fetch("presets").keys.sort ==
    expected_new_presets.sort,
  "v2 preset identifiers drifted",
)
assert(
  protocol.fetch("preset_contract_v2").fetch("presets").transform_values { |preset| preset.fetch("display_name") } == {
    "calm" => "Calm",
    "balanced_v2" => "Balanced v2",
    "frequent_reset" => "Frequent reset",
    "adaptive" => "Adaptive",
    "custom_v2" => "Custom",
  },
  "v2 preset display names drifted",
)
assert(
  protocol.dig("preset_contract_v2", "legacy_identifier_disposition").keys
    .reject { |key| key == "rule" }.sort == expected_legacy_profiles.sort,
  "legacy profile disposition is incomplete",
)
assert(
  protocol.dig("preset_contract_v2", "new_install_default") == "balanced_v2",
  "new-install default must be balanced_v2",
)
assert(protocol.dig("preset_contract_v2", "contract_version") == 2, "v2 preset contract needs version 2")
assert(
  protocol.dig("preset_contract_v2", "persisted_selection_requires") ==
    %w[preset_contract_version preset_identifier migration_state],
  "persisted v2 selection must disambiguate version, identifier, and migration state",
)
assert(
  protocol.dig("preset_contract_v2", "migration_states") ==
    %w[legacy_unmigrated v2_selected v2_migrated_with_explicit_acceptance],
  "preset migration states drifted",
)
adaptive = protocol.dig("preset_contract_v2", "presets", "adaptive")
assert(
  adaptive.fetch("initial_bounds_from") == "balanced_v2" &&
    adaptive.fetch("frequency_changes_allowed") == false &&
    adaptive.fetch("allowed_initial_adaptation") ==
      %w[delivery_within_window bounded_automatic_holds],
  "Adaptive must initially change only delivery and bounded holds",
)
custom_v2 = protocol.dig("preset_contract_v2", "presets", "custom_v2")
assert(custom_v2.fetch("payload_schema_version") == 2, "custom_v2 payload schema drifted")
legacy_custom = protocol.dig("preset_contract_v2", "legacy_identifier_disposition", "custom")
assert(
  legacy_custom.fetch("suggested_successor") == "custom_v2" &&
    legacy_custom.fetch("payload_compatibility").include?("exact v1 custom timing fields") &&
    legacy_custom.fetch("payload_compatibility").include?("does not reinterpret timing"),
  "legacy custom migration must preserve its exact payload",
)
assert(
  protocol.dig("preset_contract_v2", "recovery").values_at(
    "eligible_after_seconds",
    "latest_typical_seconds",
    "suggested_duration_min_seconds",
    "suggested_duration_max_seconds",
    "required_movement_deferrals",
    "maximum_offers_per_session",
  ) == [5400, 7200, 300, 600, 2, 1],
  "v2 recovery values drifted",
)
expected_v2_presets.each do |identifier, expected|
  preset = protocol.dig("preset_contract_v2", "presets", identifier)
  assert(
    [
      preset.dig("visual", "soft_due_seconds"),
      preset.dig("visual", "target_seconds"),
      preset.dig("visual", "latest_preferred_seconds"),
      preset.dig("visual", "duration_seconds"),
    ] == expected.fetch("visual"),
    "#{identifier} visual values drifted",
  )
  assert(
    [
      preset.dig("movement", "soft_due_seconds"),
      preset.dig("movement", "target_seconds"),
      preset.dig("movement", "latest_preferred_seconds"),
      preset.dig("movement", "recommended_duration_seconds"),
      preset.dig("movement", "quick_duration_seconds"),
    ] == expected.fetch("movement"),
    "#{identifier} movement values drifted",
  )
  assert(
    preset.fetch("position_target_seconds") == expected.fetch("position"),
    "#{identifier} position value drifted",
  )
end
assert(
  protocol.dig("preset_contract_v2", "legacy_identifier_disposition", "research_informed_high_frequency", "suggested_successor") == "custom_v2" &&
    protocol.dig("preset_contract_v2", "legacy_identifier_disposition", "research_informed_high_frequency", "successor_seed") == "exact_v1_snapshot",
  "legacy high-frequency migration must seed exact values into custom_v2",
)
assert(
  protocol.fetch("activity_estimator").values_at(
    "recent_input_window_seconds",
    "long_idle_reset_seconds",
    "wake_unlock_grace_seconds",
    "return_from_long_idle_grace_seconds",
    "expected_sample_seconds",
    "maximum_covered_sample_gap_seconds",
  ) == [60, 300, 90, 60, 5, 15],
  "activity thresholds drifted",
)
expected_clock_meanings = {
  "visual" => "visual_reset_schedule_based_on_estimated_active_computer_use",
  "movement" => "movement_opportunity_schedule_based_on_estimated_active_computer_use",
  "position" => "optional_position_change_schedule_based_on_estimated_active_computer_use_or_user_interval",
  "recovery" => "optional_recovery_schedule_from_eligible_interaction_time_and_explicit_deferrals",
}
assert(protocol.fetch("clock_semantics_v2").slice(*expected_clocks) == expected_clock_meanings, "clock meanings must stay honest")
assert(
  runtime.fetch("clock_contract").slice(*expected_clocks).transform_values { |clock| clock.fetch("meaning") } == expected_clock_meanings,
  "runtime clock meanings differ",
)
assert(
  protocol.dig("clock_semantics_v2", "prohibited_permission_free_inferences") ==
    %w[gaze near_screen_exposure body_movement body_stillness body_position position_stability posture],
  "permission-free inference prohibitions drifted",
)
expected_boundaries = {
  "deadline_reached" => "elapsed_seconds_greater_than_or_equal_to_deadline_seconds",
  "recent_input_eligible" => "seconds_since_input_less_than_or_equal_to_60",
  "long_idle_begins" => "seconds_since_input_greater_than_or_equal_to_300",
  "valid_covered_sample" => "adjacent_interval_seconds_less_than_or_equal_to_15",
  "corridor_releases" => "elapsed_seconds_greater_than_or_equal_to_corridor_seconds",
  "snooze_reoffers" => "elapsed_seconds_greater_than_or_equal_to_selected_snooze_seconds",
}
assert(protocol.fetch("boundary_predicates") == expected_boundaries, "protocol boundary predicates drifted")
runtime_boundaries = runtime.dig("time", "boundary_predicates")
assert(runtime_boundaries.fetch("long_idle_begins") == expected_boundaries.fetch("long_idle_begins"), "300-second boundary drifted")
assert(runtime_boundaries.fetch("release_corridor_ends") == expected_boundaries.fetch("corridor_releases"), "90-second release boundary drifted")
assert(runtime_boundaries.fetch("snooze_reoffers") == expected_boundaries.fetch("snooze_reoffers"), "snooze equality boundary drifted")
assert(
  protocol.dig("completion_semantics", "movement", "sensor_observation_is_completion") == false,
  "sensor observation must not become movement completion",
)
assert(
  runtime.dig("product_facts", "closed_vocabulary") == expected_facts,
  "closed product fact order or membership drifted",
)
assert(
  event.dig("x_contract_status", "product_fact_mapping").values == expected_facts,
  "legacy event-schema mapping must project exactly the ten product facts",
)
assert(
  event.dig("x_contract_status", "new_writes_allowed") == false,
  "legacy event schema must remain read-only",
)

transitions = runtime.dig("action_contract", "transitions")
clock_effects = runtime.dig("action_contract", "clock_effect_definitions").keys
assert(transitions.is_a?(Array) && !transitions.empty?, "transitions must be present")
assert(
  transitions.map { |transition| transition.fetch("id") }.uniq.length == transitions.length,
  "transition identifiers must be unique",
)
transitions.each do |transition|
  id = transition.fetch("id")
  assert(
    transition.fetch("clocks").keys.sort == expected_clocks.sort,
    "#{id} must declare all four clock effects",
  )
  transition.fetch("clocks").each_value do |effect|
    assert(clock_effects.include?(effect), "#{id} uses undefined clock effect #{effect}")
  end
  %w[terminal facts ledgers visible stale recovery].each do |field|
    assert(transition.key?(field), "#{id} is missing #{field}")
  end
  assert(
    (transition.fetch("facts") - expected_facts).empty?,
    "#{id} uses a fact outside the closed vocabulary",
  )
  assert(transition.fetch("facts").length <= 1, "#{id} emits more than one product fact")
  if transition.fetch("facts").any?
    assert(transition.fetch("ledgers").include?("product_fact"), "#{id} facts require product_fact ledger")
  end
  if id.start_with?("sensor.")
    assert(transition.fetch("facts").empty?, "#{id} cannot create a product fact")
  end
end
transition_ids = transitions.map { |transition| transition.fetch("id") }
guards = runtime.dig("action_contract", "transition_guards")
phase_graph = runtime.dig("action_contract", "opportunity_phase_graph")
phases = phase_graph.fetch("phases")
edges = phase_graph.fetch("edges")
assert(guards.keys.sort == transition_ids.sort, "every transition needs exactly one canonical guard")
assert(edges.keys.sort == phases.sort, "phase graph must define edges for every canonical phase")
guards.each do |id, guard|
  %w[phase_scope source_phases target_phase opportunity_kinds participant_guard required_payload].each do |field|
    assert(guard.key?(field), "#{id} guard is missing #{field}")
  end
  assert(guard.fetch("source_phases").is_a?(Array) && !guard.fetch("source_phases").empty?, "#{id} needs source phases")
  assert(guard.fetch("opportunity_kinds").is_a?(Array) && !guard.fetch("opportunity_kinds").empty?, "#{id} needs opportunity kinds")
  assert(guard.fetch("required_payload").is_a?(Array) && !guard.fetch("required_payload").empty?, "#{id} needs an explicit payload contract")
  if %w[opportunity opportunity_origin].include?(guard.fetch("phase_scope"))
    guard.fetch("source_phases").each do |source|
      next if source == "none"
      assert(phases.include?(source), "#{id} uses unknown source phase #{source}")
      target = guard.fetch("target_phase")
      next if target == "unchanged" || target.start_with?("payload_selected_")
      assert(phases.include?(target), "#{id} uses unknown target phase #{target}")
      assert(edges.fetch(source).include?(target), "#{id} source #{source} cannot reach #{target}")
    end
  end
end
required_merged = %w[
  merged.accept
  merged.visual_segment_finished
  merged.visual_segment_done_early
  merged.movement_accept
  merged.movement_timer_finished
  merged.movement_done_early
  merged.movement_already_moved
  merged.movement_change_content
  merged.movement_position_changed
  merged.movement_skip
  merged.visual_only
  merged.escape_during_visual
  merged.escape_during_movement
]
assert((required_merged - transition_ids).empty?, "phase-specific merged transition coverage is incomplete")
movement_accept_guard = guards.fetch("now.accept_movement")
assert(
  movement_accept_guard.fetch("source_phases") == ["movement_offered"] &&
    movement_accept_guard.fetch("required_payload") == ["selected_duration_seconds_300_or_120"],
  "movement acceptance must originate offered and carry the chosen duration",
)
assert(guards.fetch("movement.done_early").fetch("source_phases") == ["movement_running"], "Done early is running-only")
assert(guards.fetch("movement.timer_finished").fetch("source_phases") == ["movement_running"], "movement timer is running-only")
transition_by_id = transitions.to_h { |transition| [transition.fetch("id"), transition] }
assert(
  transition_by_id.fetch("now.accept_visual").fetch("clocks") == {
    "visual" => "freeze", "movement" => "continue_eligibility", "position" => "freeze", "recovery" => "continue_eligibility",
  },
  "accepted visual must freeze its direct visual/position eligibility",
)
%w[now.accept_movement now.accept_recovery merged.accept].each do |id|
  assert(
    transition_by_id.fetch(id).fetch("clocks").values.all? { |effect| effect == "freeze" },
    "#{id} must freeze every schedule clock during the accepted ritual",
  )
end
assert(
  transition_by_id.fetch("merged.movement_accept").fetch("clocks") == {
    "visual" => "retain", "movement" => "freeze", "position" => "freeze", "recovery" => "freeze",
  },
  "merged movement acceptance must retain finished visual and freeze the running ritual scopes",
)
%w[merged.visual_segment_finished merged.visual_segment_done_early].each do |id|
  transition = transition_by_id.fetch(id)
  assert(transition.fetch("visible").include?("movement_duration_offer"), "#{id} must reach the movement offer")
  assert(transition.fetch("stale") == "reconcile_visual_segment_candidate", "#{id} must reconcile the visual segment")
  assert(transition.fetch("recovery") == "retain_visual_effect_even_if_movement_later_ends", "#{id} must retain visual completion")
end
%w[
  merged.movement_timer_finished
  merged.movement_done_early
  merged.movement_already_moved
  merged.movement_position_changed
  merged.movement_skip
  merged.escape_during_movement
].each do |id|
  transition = transition_by_id.fetch(id)
  assert(transition.dig("clocks", "visual") == "retain", "#{id} must retain the already-fresh visual cycle")
end
assert(
  transitions.any? { |transition| transition["id"] == "opportunity.presented" && transition["facts"] == ["promptPresented"] },
  "promptPresented needs an exact transition",
)
assert(
  expected_facts.all? { |fact| transitions.any? { |transition| transition.fetch("facts").include?(fact) } },
  "every product fact needs at least one exact transition",
)

paused = runtime.dig("presentation_states", "paused", "reasons")
held = runtime.dig("presentation_states", "held", "reasons")
assert((paused & held).empty?, "Paused and Held reasons must be disjoint")
assert(
  protocol.dig("state_semantics_v2", "manual_pause_options") ==
    runtime.dig("presentation_states", "manual_pause_options"),
  "manual pause options differ between protocol and runtime contract",
)
assert(
  protocol.dig("state_semantics_v2", "paused", "reasons") == paused,
  "Paused reasons differ between protocol and runtime contract",
)
assert(
  protocol.dig("state_semantics_v2", "paused", "reason_clock_scope") ==
    runtime.dig("presentation_states", "paused", "reason_clock_scope"),
  "Paused clock scopes differ between protocol and runtime contract",
)
assert(
  protocol.dig("state_semantics_v2", "held", "reasons") == held,
  "Held reasons differ between protocol and runtime contract",
)
assert(
  runtime.dig("presentation_states", "paused", "reason_clock_scope", "accepted_visual_ritual") ==
    %w[visual position] &&
    runtime.dig("presentation_states", "paused", "reason_clock_scope", "accepted_movement_merged_or_recovery_ritual") ==
      expected_clocks,
  "accepted rituals must freeze position accrual consistently",
)
held_evidence = runtime.dig("presentation_states", "held", "evidence_contract")
assert(
  held_evidence.fetch("required") ==
    %w[provenance_kind source_capability_id observed_at_utc expires_at_utc_or_explicit_end qualification correction_action_when_automatic],
  "hold evidence provenance/freshness contract drifted",
)
assert(
  held_evidence.fetch("confirmed_away_requires").include?("fresh_unambiguous_authorized_evidence") &&
    held_evidence.fetch("stale_missing_or_conflicting") == "unknown_no_hold_no_pause_no_body_claim",
  "hold evidence must fail stale or unqualified input to unknown",
)
assert(
  protocol.fetch("suppression_precedence") == runtime.dig("presentation_states", "collision_precedence"),
  "presentation precedence differs between protocol and runtime contract",
)
assert(
  runtime.dig("presentation_states", "release_corridors_seconds") == {
    "wake_or_unlock" => 90,
    "return_from_long_idle" => 60,
    "hold_release" => 90,
    "manual_pause_resume" => 90,
    "working_hours_reentry" => 60,
  },
  "release corridors drifted",
)
assert(
  protocol.fetch("opportunity_delivery").values_at(
    "post_hold_landing_corridor_seconds",
    "post_manual_pause_resume_corridor_seconds",
    "working_hours_reentry_corridor_seconds",
  ) == [90, 90, 60],
  "delivery corridors drifted",
)
assert(
  runtime.dig("time", "observation_gap", "expected_sample_seconds") == 5 &&
    runtime.dig("time", "observation_gap", "maximum_covered_interval_seconds") == 15,
  "portable monotonic gap policy drifted",
)
deadline = runtime.dig("time", "accepted_ritual_deadline")
assert(
  runtime.dig("time", "wall_metadata", "purpose") == "display_exchange_and_audit_only_never_countdown_reconstruction" &&
    deadline.fetch("epoch_or_anchor_discontinuity") == "remaining_is_zero_and_timer_finished_is_reconciled_once" &&
    deadline.fetch("wall_clock_change") == "ignored_for_countdown",
  "accepted deadline fallback must never extend duration from wall time",
)
assert(
  deadline.dig("handoff", "acknowledgement_requires") ==
    %w[deadline_id_and_opportunity_revision sender_epoch_and_send_ticks receiver_epoch_and_receive_ticks bounded_round_trip_uncertainty final_sender_commit_ticks] &&
    deadline.dig("handoff", "commit_rule").include?("minus the full measured uncertainty bound"),
  "deadline handoff requires a bounded monotonic acknowledgement",
)
assert(
  runtime.dig("input_and_motion", "declaration_guard_seconds") == 0,
  "D-032 requires no declaration-key delay",
)
movement_a11y = runtime.dig("input_and_motion", "movement_acceptance")
assert(
  movement_a11y.dig("offered_state", "timer_running") == false &&
    movement_a11y.dig("offered_state", "done_early_present") == false &&
    movement_a11y.dig("offered_state", "initial_focus") == "start_5_minutes" &&
    movement_a11y.dig("offered_state", "focus_order") ==
      %w[start_5_minutes start_2_minutes already_moved change_position skip],
  "movement offered state accessibility contract drifted",
)
assert(
  movement_a11y.dig("running_state", "timer_running") == true &&
    movement_a11y.dig("running_state", "selected_duration_required") == true &&
    movement_a11y.dig("running_state", "initial_focus") == "done_early" &&
    movement_a11y.dig("running_state", "focus_order") ==
      %w[walk_or_wheel small_space seated done_early already_moved change_position skip],
  "movement running state accessibility contract drifted",
)
assert(
  movement_a11y.dig("offered_state", "controls_first_frame", "start_5_minutes", "shortcut") == %w[return 5] &&
    movement_a11y.dig("offered_state", "controls_first_frame", "start_2_minutes", "shortcut") == %w[q 2] &&
    runtime.dig("input_and_motion", "first_active_frame").include?("movement_offered_shortcuts_5_2_q_a_p"),
  "movement 5/2 acceptance actions must work on the first frame",
)
nonterminal = runtime.dig("action_contract", "nonterminal_reconciliation")
assert(
  nonterminal.fetch("rule").include?("Arrival order is never an input") &&
    nonterminal.fetch("winner_sort_key") == %w[smallest_intent_rank lexicographically_smallest_action_id],
  "nonterminal reconciliation must be deterministic and arrival-independent",
)
assert(
  runtime.dig("terminal_reconciliation", "rules").include?(
    "arrival_order_never_selects_the_winner",
  ),
  "terminal reconciliation must be order-independent",
)
terminal = runtime.fetch("terminal_reconciliation")
assert(
  terminal.fetch("originated_after_known_closure") == "invalid_audited_no_op" &&
    terminal.fetch("arrived_after_provisional_closure_but_valid_at_origin") == "include_in_candidate_set",
  "late valid candidates and post-closure-originated actions must remain distinct",
)
assert(
  terminal.fetch("terminal_claim_rank_smallest_wins") == {
    "skipped" => 0,
    "snoozed" => 5,
    "notAppropriate" => 10,
    "positionChanged" => 20,
    "userDeclaredAlreadyMoved" => 30,
    "userDeclaredCompleted" => 40,
    "timerFinished" => 50,
  },
  "terminal fact-claim order drifted",
)
assert(
  terminal.fetch("winner_sort_key") == %w[
    smallest_terminal_claim_rank
    lexicographically_smallest_registered_action_kind
    lexicographically_smallest_origin_device_id
    smallest_origin_device_counter
    lexicographically_smallest_action_id
  ] &&
    terminal.fetch("rules").include?("unsynchronized_wall_time_remaining_duration_and_segment_duration_never_rank_candidates"),
  "terminal winner order must use logical metadata, never wall or incomparable duration",
)
rebase = terminal.fetch("rebase_contract")
assert(
  rebase.fetch("retained_preterminal_snapshot_requires").include?("every_participant_clock_cycle_id_accumulated_time_and_phase") &&
    rebase.fetch("apply_rule").include?("apply the new winner exactly once") &&
    rebase.fetch("apply_rule").include?("keep already-final independent merged-component effects") &&
    rebase.fetch("fact_rule").include?("Upsert the same deterministic terminal fact ID") &&
    rebase.fetch("fact_rule").include?("repeat an accessibility announcement"),
  "late-winner rebase must restore one snapshot without duplicate effects",
)
%w[clock_cycle_id opportunity_id action_id decision_id device_id session_id].each do |identity|
  assert(runtime.fetch("identities").key?(identity), "missing #{identity} contract")
end

root = Pathname.new(protocol_path).dirname.parent.parent.parent
product_model = root.join("design/PRODUCT_MODEL.md").read
interaction = root.join("design/INTERACTION_SPEC.md").read
screens = root.join("design/SCREEN_INVENTORY.md").read
copy = root.join("design/COPY_INVENTORY.md").read
assert(product_model.include?("Exhaustive fresh-cycle effects"), "PRODUCT_MODEL fresh-cycle table must declare its scope")
%w[snooze skip capsule position recovery merged].each do |variant|
  assert(product_model.downcase.include?(variant), "PRODUCT_MODEL fresh-cycle table is missing #{variant}")
end
assert(!interaction.include?("greatest recorded remaining milliseconds"), "prose still ranks terminal actions by remaining duration")
assert(!interaction.include?("wall deadline reconstructs remaining"), "prose still reconstructs accepted deadlines from wall time")
[
  "Calm",
  "Balanced v2",
  "Frequent reset",
  "Adaptive",
  "Custom",
  "custom_v2",
].each do |name|
  assert(copy.include?(name), "canonical preset copy is missing #{name}")
end
[
  "Held · selected busy time until 3:00",
  "Held · Focus you selected",
  "Held · selected app is active",
  "Held · likely call",
  "Keep current schedule",
  "Review new schedule",
].each do |phrase|
  assert(copy.include?(phrase), "canonical copy is missing #{phrase}")
end
copy.each_line do |line|
  if line.include?("On hold") || line.include?("Paused: busy")
    assert(line.include?("Legacy current-runtime") || line.include?("legacy"), "old hold copy must be explicitly legacy")
  end
end
assert(screens.include?('hold = dashed ring + the word "Held"'), "K.3 meaning-without-color must say Held")
RUBY

if /usr/bin/grep -Eq 'Same \(D-031\)|D-013…D-025|D-013/D-021|first-class \(D-018, D-023\)|only surface \(D-018\)' \
  "$ROOT/design/INTERACTION_SPEC.md" \
  "$ROOT/design/SCREEN_INVENTORY.md" \
  "$ROOT/design/DESIGN_SYSTEM.md" \
  "$ROOT/design/DECISIONS.md"; then
  echo "Known quarantined decision citation remains in canonical design files." >&2
  exit 1
fi

echo "check-protocol-configuration: OK"
