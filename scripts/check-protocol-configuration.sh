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
    "balanced_v2" => "Balanced",
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
transition_by_id = transitions.to_h { |transition| [transition.fetch("id"), transition] }
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
      next if %w[none any_nonclosed].include?(source)
      assert(phases.include?(source), "#{id} uses unknown source phase #{source}")
      target = guard.fetch("target_phase")
      next if %w[unchanged dynamic_full_evidence_projection].include?(target) || target.start_with?("payload_selected_")
      assert(phases.include?(target), "#{id} uses unknown target phase #{target}")
      assert(edges.fetch(source).include?(target), "#{id} source #{source} cannot reach #{target}")
    end
  end
end

participants = runtime.dig("action_contract", "participant_contract")
base_sets = participants.fetch("registered_base_sets")
assert(base_sets == {
  "visual" => %w[visual],
  "movement" => %w[movement],
  "position" => %w[position],
  "recovery" => %w[visual movement recovery],
  "merged" => %w[visual movement],
}, "registered base participant sets drifted")
specific_guards = participants.fetch("guard_meanings").slice(
  "exactly_visual",
  "exactly_movement",
  "exactly_position",
  "exactly_visual_movement_and_recovery",
  "exactly_visual_and_movement",
)
affected_actions = participants.fetch("affected_nonparticipant_actions")
guards.each do |id, guard|
  next unless %w[opportunity opportunity_origin].include?(guard.fetch("phase_scope"))

  guard.fetch("opportunity_kinds").each do |kind|
    next if kind == "none"
    base = base_sets.fetch(kind)
    participant_guard = guard.fetch("participant_guard")
    if specific_guards.key?(participant_guard)
      assert(specific_guards.fetch(participant_guard) == base, "#{id} participant guard cannot match #{kind}")
    else
      assert(
        %w[exact_registered_participant_set nonempty_subset_of_registered_participants].include?(participant_guard),
        "#{id} uses an opportunity participant guard without compatible semantics",
      )
    end
    affected = guard.fetch("affected_nonparticipants", [])
    assert((affected & base).empty?, "#{id} affected nonparticipant overlaps its base participant set")
  end
  assert(
    guard.fetch("affected_nonparticipants", []) == affected_actions.fetch(id, []),
    "#{id} affected-nonparticipant guard differs from the participant registry",
  )
end

resolver_groups = runtime.dig("action_contract", "resolver_membership").reject { |name, _| name == "rule" }
resolved_ids = resolver_groups.values.flatten
assert(resolved_ids.sort == transition_ids.sort, "every transition must belong to one named resolver")
assert(resolved_ids.uniq.length == resolved_ids.length, "a transition belongs to multiple resolvers")
resolver_groups.each do |name, ids|
  expected_terminal = {
    "authoritative_opportunity_nonterminal" => false,
    "authoritative_global_nonterminal" => false,
    "merged_visual_cross_slot_candidate_set" => nil,
    "terminal_candidate_set" => true,
    "operational_terminal_disposition" => true,
  }.fetch(name)
  ids.each do |id|
    next if expected_terminal.nil?
    assert(transition_by_id.fetch(id).fetch("terminal") == expected_terminal, "#{id} terminal flag conflicts with #{name}")
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
movement_open_guard = guards.fetch("now.open_movement_offer")
assert(
  movement_open_guard.fetch("source_phases") == ["heads_up"] &&
    movement_open_guard.fetch("target_phase") == "movement_offered" &&
    transition_by_id.fetch("now.open_movement_offer").fetch("facts").empty? &&
    transition_by_id.fetch("now.accept_movement").fetch("facts") == ["breakStarted"],
  "movement Now must open offered without a fact; only 5/2 acceptance starts the break",
)
%w[now.accept_visual merged.accept].each do |id|
  assert(transition_by_id.fetch(id).fetch("facts") == ["breakStarted"], "#{id} must start its visual field immediately")
end
assert(guards.fetch("movement.done_early").fetch("source_phases") == ["movement_running"], "Done early is running-only")
assert(guards.fetch("movement.timer_finished").fetch("source_phases") == ["movement_running"], "movement timer is running-only")

offered_running_pairs = {
  "movement.position_changed" => ["movement.position_changed_offered", "movement.position_changed_running", "visual"],
  "movement.skip" => ["movement.skip_offered", "movement.skip_running", "visual"],
  "movement.escape" => ["movement.escape_offered", "movement.escape_running", "visual"],
  "recovery.skip" => ["recovery.skip_offered", "recovery.skip_running", "visual"],
  "recovery.escape" => ["recovery.escape_offered", "recovery.escape_running", "visual"],
}
offered_running_pairs.each do |label, (offered_id, running_id, clock)|
  assert(guards.fetch(offered_id).fetch("source_phases").all? { |phase| phase.end_with?("_offered") }, "#{label} offered guard is not offered-only")
  assert(guards.fetch(running_id).fetch("source_phases").all? { |phase| phase.end_with?("_running") }, "#{label} running guard is not running-only")
  assert(transition_by_id.fetch(offered_id).dig("clocks", clock) == "retain", "#{offered_id} must preserve offer-time accrual")
  assert(transition_by_id.fetch(running_id).dig("clocks", clock) == "restore_pre_ritual", "#{running_id} must use the acceptance snapshot")
end
%w[movement.position_changed_offered movement.position_changed_running].each do |id|
  assert(guards.fetch(id).fetch("participant_guard") == "exactly_movement", "#{id} must retain movement base participants")
  assert(guards.fetch(id).fetch("affected_nonparticipants") == ["position"], "#{id} must guard position as affected nonparticipant")
end
assert(
  guards.fetch("merged.movement_position_changed").fetch("participant_guard") == "exactly_visual_and_movement" &&
    guards.fetch("merged.movement_position_changed").fetch("affected_nonparticipants") == ["position"],
  "merged position action must retain visual+movement base participants",
)
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
  assert(transition.fetch("stale").include?("merged_visual_cross_slot_arbiter"), "#{id} must reconcile through the cross-slot arbiter")
  assert(transition.fetch("recovery").include?("only_if_cross_slot_arbiter_commits"), "#{id} must not become final before cross-slot settlement")
end
cross_slot = runtime.dig("action_contract", "merged_visual_cross_slot_arbiter")
assert(
  cross_slot &&
    cross_slot.fetch("competing_transition_ids") == %w[
      merged.escape_during_visual
      merged.visual_segment_done_early
      merged.visual_segment_finished
    ] &&
    cross_slot.fetch("requires_same_origin") == %w[opportunity_id coordinator_generation opportunity_revision visual_segment_id] &&
    cross_slot.fetch("winner_rank_smallest_wins") == {
      "merged.escape_during_visual" => 0,
      "merged.visual_segment_done_early" => 10,
      "merged.visual_segment_finished" => 20,
    } &&
    cross_slot.fetch("loser_effect") == "operational_rejected_no_op_no_fact_no_clock_effect" &&
    cross_slot.fetch("already_committed_component_rule").include?("merged.escape_during_movement"),
  "merged visual completion and same-revision parent Escape need one cross-slot arbiter",
)
assert(
  resolver_groups.fetch("merged_visual_cross_slot_candidate_set").sort == cross_slot.fetch("competing_transition_ids").sort &&
    cross_slot.fetch("component_finality").include?("create no timerFinished") &&
    cross_slot.fetch("convergence").include?("both timerFinished and skipped") &&
    cross_slot.fetch("convergence").include?("Arrival time and wall time are not inputs") &&
    guards.fetch("merged.escape_during_visual").fetch("required_payload").include?("coordinator_generation") &&
    %w[merged.visual_segment_finished merged.visual_segment_done_early merged.escape_during_visual].all? do |id|
      guards.fetch(id).fetch("source_phases") == ["merged_visual_running"] &&
        transition_by_id.fetch(id).dig("clocks", "visual") == "fresh_cycle"
    end,
  "cross-slot resolver must own the exact same-revision race and one visual successor path",
)
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
assert(
  runtime.dig("clock_contract", "position", "explicit_action_eligibility").include?("while position accrual is frozen") &&
    runtime.dig("clock_contract", "position", "explicit_action_eligibility").include?("does not complete movement"),
  "explicit position actions must remain reachable without conflating accrual or movement",
)
latent_position = runtime.dig("clock_contract", "position", "latent_manual_cycle")
assert(
  latent_position &&
    latent_position.fetch("always_present") == true &&
    latent_position.fetch("disabled_schedule_state") == "manual_only_no_accrual_no_due_no_offer" &&
    latent_position.fetch("explicit_position_changed_effect") == "rotate_latent_cycle_without_enabling_reminders" &&
    %w[movement.position_changed_offered movement.position_changed_running merged.movement_position_changed].all? do |id|
      guards.fetch(id).fetch("required_payload").include?("affected_position_cycle_id")
    end,
  "disabled position reminders still need a reachable latent manual cycle",
)
assert(
  protocol.dig("clock_semantics_v2", "position_manual_cycle") == {
    "always_present" => true,
    "disabled_schedule_state" => "manual_only_no_accrual_no_due_no_offer",
    "explicit_change_rotates_cycle" => true,
    "explicit_change_enables_reminders" => false,
  },
  "health protocol position-disabled lifecycle drifted",
)
%w[
  movement.position_changed_offered
  movement.position_changed_running
  position.changed
  position.skip
  merged.movement_position_changed
].each do |id|
  assert(
    transition_by_id.fetch(id).dig("clocks", "position") == "rotate_position_cycle_preserving_enablement",
    "#{id} must rotate position without enabling reminders",
  )
end
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
    deadline.fetch("epoch_or_anchor_discontinuity") == "timerRecoveryUnavailable_operational_only_no_product_fact_no_fresh_cycle" &&
    deadline.fetch("wall_clock_change") == "ignored_for_countdown",
  "unknown accepted timing must not manufacture completion or a fresh schedule",
)
assert(
  deadline.dig("handoff", "acknowledgement_requires") ==
    %w[deadline_id_and_opportunity_revision sender_epoch_and_send_ticks receiver_epoch_and_receive_ticks bounded_round_trip_uncertainty final_sender_commit_ticks] &&
    deadline.dig("handoff", "commit_rule").include?("minus the full measured uncertainty bound"),
  "deadline handoff requires a bounded monotonic acknowledgement",
)
timer_recovery = transition_by_id.fetch("system.timer_recovery_unavailable")
assert(
  timer_recovery.fetch("facts").empty? &&
    timer_recovery.fetch("ledgers") == ["operational"] &&
    timer_recovery.fetch("clocks").values.all? { |effect| effect == "retain" } &&
    deadline.dig("recovery_unavailable", "grace_seconds") == 60 &&
    deadline.dig("recovery_unavailable", "product_facts") == [] &&
    deadline.dig("recovery_unavailable", "grace_begins") == "after_signed_fence_and_operational_disposition_commit" &&
    timer_recovery.fetch("recovery").include?("commit_signed_projection_fence"),
  "unknown timer recovery must remain operational-only and preserve every due schedule",
)
assert(
  guards.fetch("system.timer_recovery_unavailable").fetch("source_phases").sort ==
    %w[merged_movement_running merged_visual_running movement_running recovery_running visual_running] &&
    guards.fetch("system.timer_recovery_unavailable").fetch("required_payload").include?("unavailable_epoch_or_anchor_reason") &&
    guards.fetch("system.timer_recovery_unavailable").fetch("required_payload").include?("signed_high_water_fence_checkpoint"),
  "unknown timer recovery must guard every running ritual phase",
)
unavailable = runtime.dig("time", "system_unavailable_interval")
extended_unavailable = transition_by_id.fetch("system.available_after_extended_unavailable")
assert(
  unavailable.fetch("anchor") == "continuous_monotonic_epoch_and_start_ticks" &&
    unavailable.fetch("return_rule").include?("at least 300 seconds") &&
    extended_unavailable.fetch("facts") == ["likelyNaturalInterruption"] &&
    extended_unavailable.dig("clocks", "visual") == "fresh_cycle" &&
    extended_unavailable.fetch("recovery").include?("same_epoch_unavailable_elapsed_at_least_300"),
  "proven five-minute system unavailability must give visual courtesy without movement credit",
)
assert(
  protocol.dig("activity_estimator", "system_unavailable_visual_courtesy_seconds") == 300 &&
    protocol.dig("activity_estimator", "system_unavailable_return_grace_seconds") == 60 &&
    protocol.dig("completion_semantics", "likely_natural_interruption", "unknown_elapsed_creates_fact_or_courtesy") == false,
  "protocol system-unavailable courtesy thresholds drifted",
)
candidate_lifecycle = runtime.dig("product_facts", "candidate_data_lifecycle")
assert(
  candidate_lifecycle.fetch("class") == "class_0_ephemeral_operational_state" &&
    candidate_lifecycle.fetch("location") == "memory_only" &&
    candidate_lifecycle.fetch("maximum_retention_seconds") <= 120 &&
    candidate_lifecycle.fetch("maximum_retention_seconds") == 90 &&
    candidate_lifecycle.fetch("export") == "never" &&
    candidate_lifecycle.fetch("persistence") == "prohibited" &&
    candidate_lifecycle.fetch("stable_record_identity") == "none" &&
    protocol.dig("candidate_data_lifecycle_v2", "maximum_retention_seconds") == 90 &&
    protocol.dig("candidate_data_lifecycle_v2", "persistence") == false,
  "raw candidate lifecycle must be Class 0, memory-only, bounded, and unexported",
)
companion = runtime.fetch("companion_contract")
expected_companion_states = %w[live offline expired pending revalidating rejected_no_op already_ended transfer_failed]
assert(companion.fetch("states").keys == expected_companion_states, "companion state registry is incomplete or reordered")
expected_companion_states.each do |state|
  projection = companion.dig("states", state)
  %w[take_with_me_enabled terminal_controls_enabled recovery_control_enabled visible_status voiceover_announcement recovery_action].each do |field|
    assert(projection.key?(field), "companion #{state} is missing #{field}")
  end
end
assert(
  companion.dig("states", "live", "take_with_me_enabled") == true &&
    companion.dig("states", "live", "terminal_controls_enabled") == true &&
    expected_companion_states.drop(1).all? { |state| companion.dig("states", state, "take_with_me_enabled") == false } &&
    expected_companion_states.drop(1).all? { |state| companion.dig("states", state, "terminal_controls_enabled") == false } &&
    companion.fetch("live_scope_rule").include?("coordinator generation") &&
    companion.dig("interaction", "escape_rule").include?("never_cancel_or_finish") &&
    companion.fetch("sensor_free_fallback").include?("without HealthKit, motion, location, camera"),
  "companion controls must be live-generation gated, explicit, accessible, and sensor-free",
)
timer_projection = runtime.fetch("timer_recovery_user_projection")
assert(
  timer_projection.dig("exact_copy", "title") == "Timer couldn’t be restored" &&
    timer_projection.dig("exact_copy", "body") == "No finish was recorded. This schedule is still due." &&
    timer_projection.dig("exact_copy", "menu_status") == "Still due · timer not restored" &&
    timer_projection.dig("interaction", "initial_focus") == "close_action" &&
    timer_projection.dig("interaction", "quiet_transition").include?("60_second_grace"),
  "timer recovery user projection must be neutral, localized, focused, and still due",
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
assert(
  movement_a11y.dig("offered_state", "controls_first_frame", "change_position", "action") == "movement.position_changed_offered" &&
    movement_a11y.dig("running_state", "controls_first_frame", "change_position", "action") == "movement.position_changed_running" &&
    movement_a11y.dig("offered_state", "controls_first_frame", "skip", "action") == "movement.escape_offered" &&
    movement_a11y.dig("running_state", "controls_first_frame", "skip", "action") == "movement.escape_running",
  "movement first-frame controls must use phase-specific action IDs",
)
merged_control = movement_a11y.fetch("merged_offered_addition")
assert(
  merged_control.fetch("visibility") == "merged_movement_offered_only" &&
    merged_control.fetch("focus_position") == "after_change_position_before_skip" &&
    merged_control.dig("control", "accessible_name") == "Just the visual one" &&
    merged_control.dig("control", "shortcut") == ["v"] &&
    merged_control.dig("control", "action") == "merged.visual_only" &&
    merged_control.fetch("first_frame").include?("pointer"),
  "merged visual-only action needs exact focus, name, V shortcut, and first-frame pointer behavior",
)
nonterminal = runtime.dig("action_contract", "nonterminal_reconciliation")
assert(
  nonterminal.fetch("rule").downcase.include?("arrival order is never an input") &&
    nonterminal.fetch("winner_sort_key") == %w[causally_satisfied_exact_scope_revision smallest_authoritative_transition_rank lexicographically_smallest_action_id],
  "nonterminal reconciliation must be deterministic and arrival-independent",
)
coordinator = runtime.dig("action_contract", "authoritative_action_coordinator")
scope_contract = coordinator["scope_contract"]
assert(
  scope_contract &&
    scope_contract.dig("opportunity", "identity_fields") == %w[opportunity_id opportunity_revision] &&
    scope_contract.dig("global", "identity_fields") == %w[global_state_id global_state_revision] &&
    scope_contract.dig("global", "forbidden_fields") == ["opportunity_id"] &&
    runtime.dig("identities", "global_state_id", "stable_through").include?("relaunch"),
  "authoritative leases must separate opportunity and global scope identity",
)
authoritative_opportunity_ids = resolver_groups.fetch("authoritative_opportunity_nonterminal")
authoritative_global_ids = resolver_groups.fetch("authoritative_global_nonterminal")
authoritative_opportunity_ids.each do |id|
  assert(
    scope_contract.fetch("opportunity").fetch("phase_scopes").include?(guards.fetch(id).fetch("phase_scope")),
    "#{id} resolver and opportunity lease scope are incompatible",
  )
end
authoritative_global_ids.each do |id|
  assert(
    scope_contract.fetch("global").fetch("phase_scopes").include?(guards.fetch(id).fetch("phase_scope")),
    "#{id} resolver and global lease scope are incompatible",
  )
end
authoritative_rank = nonterminal.fetch("authoritative_transition_rank_smallest_wins")
authoritative_ids = authoritative_opportunity_ids + authoritative_global_ids
assert(
  authoritative_rank.keys.sort == authoritative_ids.sort &&
    authoritative_rank.values.uniq.length == authoritative_rank.values.length &&
    nonterminal.fetch("order_coverage_rule").include?("exactly the union"),
  "authoritative nonterminal rank must be total and match resolver membership",
)
assert(
  coordinator.fetch("lease_maximum_seconds") == 90 &&
    coordinator.fetch("rule").include?("before any product fact, deadline, phase, or clock effect") &&
    coordinator.fetch("rule").include?("offline") &&
    coordinator.fetch("rule").include?("Later cannot orphan"),
  "effect-bearing nonterminal actions require one bounded authoritative coordinator",
)
evidence_reduction = runtime.dig("presentation_states", "evidence_reduction")
assert(
  evidence_reduction.fetch("rule").include?("mutates only its named evidence record") &&
    evidence_reduction.dig("running_projection", "rule").include?("Preserve the exact running opportunity phase") &&
    evidence_reduction.dig("running_projection", "rule").include?("resume that same running segment immediately") &&
    evidence_reduction.dig("nonrunning_projection", "else_after_release") == "release_corridor",
  "Paused/Held must project the full evidence set without stranding running rituals",
)
%w[pause.resume hold.release hold.correction_release working_hours.enter system.available].each do |id|
  guard = guards.fetch(id)
  transition = transition_by_id.fetch(id)
  assert(guard.fetch("target_phase") == "dynamic_full_evidence_projection", "#{id} must have a full-evidence dynamic target")
  assert(transition.fetch("clocks").values.all? { |effect| effect == "project_full_evidence_eligibility" }, "#{id} must reduce all evidence before projection")
  assert(transition.fetch("recovery").include?("project_full_evidence") || transition.fetch("recovery").include?("no_other_evidence"), "#{id} must not unconditionally enter a corridor")
end
%w[pause.start hold.begin working_hours.exit system.unavailable].each do |id|
  assert(guards.fetch(id).fetch("source_phases") == ["any_nonclosed"], "#{id} must remain reachable while a ritual runs")
  assert(guards.fetch(id).fetch("required_payload").include?("optional_suspended_running_state"), "#{id} must preserve suspended running state")
end
assert(
  guards.fetch("system.returned_from_long_idle").fetch("target_phase") == "dynamic_full_evidence_projection" &&
    guards.fetch("system.long_idle_began").fetch("required_payload").include?("no_unresolved_running_ritual") &&
    transition_by_id.fetch("system.returned_from_long_idle").dig("clocks", "visual") == "fresh_cycle" &&
    %w[movement position recovery].all? { |clock| transition_by_id.fetch("system.returned_from_long_idle").dig("clocks", clock) == "project_full_evidence_eligibility" },
  "long-idle courtesy must not strand a ritual or clear overlapping evidence",
)
assert(
  runtime.dig("terminal_reconciliation", "rules").include?(
    "arrival_order_never_selects_the_winner",
  ),
  "terminal reconciliation must be order-independent",
)
terminal = runtime.fetch("terminal_reconciliation")
projection_lease = runtime.dig("action_contract", "terminal_projection_lease")
fence = runtime.dig("action_contract", "generation_and_closure_fence")
all_closure_guards_are_opportunity_scoped = transitions
  .select { |transition| transition.fetch("terminal") }
  .all? do |transition|
    %w[opportunity opportunity_origin].include?(guards.fetch(transition.fetch("id")).fetch("phase_scope"))
  end
assert(
  projection_lease.fetch("maximum_seconds") == 90 &&
    projection_lease.fetch("eligibility").include?("before_lease_expiry") &&
    projection_lease.fetch("settlement").include?("acknowledged/revoked") &&
    projection_lease.fetch("settlement").include?("No wall clock") &&
    terminal.fetch("valid_candidate_requires").include?("live_terminal_projection_lease_at_monotonic_origin") &&
    terminal.fetch("rules").include?("settled_predecessor_actions_can_never_mutate_a_successor_cycle"),
  "terminal candidate origination and settlement must be monotonic, bounded, and successor-safe",
)
assert(
  fence.fetch("maximum_settlement_seconds") == 90 &&
    fence.fetch("closure_coverage_selector") == "every_action_contract_transition_whose_terminal_field_is_true" &&
    all_closure_guards_are_opportunity_scoped &&
    fence.fetch("persisted_coordinator_state_requires").include?("coordinator_generation") &&
    fence.fetch("persisted_coordinator_state_requires").include?("committed_action_counter_high_water_by_paired_device") &&
    fence.fetch("signed_fence_requires").include?("ed25519_signature_from_installation_local_coordinator_key") &&
    fence.fetch("every_opportunity_closure_order").last == "then_allow_successor_cycle_or_opportunity_eligibility" &&
    fence.fetch("coordinator_epoch_loss_order").include?("reject_every_later_arriving_old_generation_action_as_operational_no_op") &&
    fence.fetch("bounded_rule").include?("never waits for an old monotonic expiry"),
  "closure and epoch-loss fences must be persisted, signed, high-water, and bounded",
)
assert(
  terminal.fetch("originated_after_known_closure") == "operational_rejected_no_op_ephemeral_receipt" &&
    terminal.fetch("arrived_after_provisional_closure_but_valid_at_origin").include?("same_live_unfenced_coordinator_generation") &&
    terminal.fetch("arrived_after_generation_or_projection_epoch_fence") == "operational_rejected_no_op_with_user_visible_receipt" &&
    terminal.fetch("valid_candidate_requires").include?("exact_current_coordinator_generation") &&
    terminal.fetch("valid_candidate_requires").include?("exact_current_unfenced_opportunity_projection_epoch_id"),
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
fact_id = terminal.fetch("terminal_fact_id")
assert(
  fact_id.fetch("algorithm") == "sha256_over_cadence_contract_bytes_v1" &&
    fact_id.fetch("inputs") == %w[domain_literal_terminal_fact_v2 opportunity_id canonical_terminal_slot fixed_registered_component_scope_for_that_slot] &&
    fact_id.fetch("fixed_registered_component_scope") == {
      "standalone_opportunity_close" => "registered_base_participant_set_from_opportunity_creation",
      "merged_visual_segment" => ["visual"],
      "merged_opportunity_close" => %w[visual movement],
    } &&
    fact_id.fetch("invariant").include?("never ID inputs"),
  "terminal fact identity must be invariant across valid candidate winners",
)
encoding = runtime.dig("identities", "portable_canonical_encoding")
identifier_contract = runtime.dig("identities", "portable_identifier_contract")
assert(
  encoding.fetch("version") == "cadence_contract_bytes_v1" &&
    encoding.fetch("hash_algorithm") == "sha256" &&
    encoding.dig("scalar_encoding", "uuid").include?("16_network_order_bytes") &&
    encoding.dig("scalar_encoding", "string").include?("unicode_nfc_utf8") &&
    encoding.dig("collection_encoding", "set").include?("sorted_unsigned_lexicographically") &&
    encoding.fetch("prohibited_inputs") == %w[wall_time localized_copy process_hash_seed pointer_address] &&
    identifier_contract.fetch("wire_text") == "lowercase_hyphenated_rfc4122" &&
    identifier_contract.fetch("deterministic_identifier_rule").include?("explicit domain literal"),
  "portable identifier encoding is incomplete or platform-dependent",
)
rebase = terminal.fetch("rebase_contract")
candidate_transition_ids = resolver_groups.fetch("terminal_candidate_set") +
  resolver_groups.fetch("merged_visual_cross_slot_candidate_set") +
  resolver_groups.fetch("operational_terminal_disposition")
candidate_effect_closure = candidate_transition_ids.flat_map do |id|
  transition_by_id.fetch(id).fetch("clocks").keys + guards.fetch(id).fetch("affected_nonparticipants", [])
end.uniq.sort
assert(
  candidate_effect_closure == expected_clocks.sort &&
    rebase.fetch("snapshot_scope_rule").include?("union of every clock") &&
  rebase.fetch("retained_preterminal_snapshot_requires").include?("all_four_visual_movement_position_and_recovery_clock_cycle_ids_including_latent_manual_position") &&
    rebase.fetch("retained_preterminal_snapshot_requires").include?("all_four_clock_accumulated_time_due_state_eligibility_phase_and_enablement") &&
    rebase.fetch("apply_rule").include?("apply the new winner exactly once") &&
    rebase.fetch("apply_rule").include?("keep already-final independent merged-component effects") &&
    rebase.fetch("fact_rule").include?("Upsert the same deterministic terminal fact ID") &&
    rebase.fetch("fact_rule").include?("repeat an accessibility announcement"),
  "late-winner rebase must restore one snapshot without duplicate effects",
)
assert(
  rebase.dig("offered_and_running_checkpoints", "offered_terminal_action").include?("Never restore a pre-ritual snapshot") &&
    rebase.dig("offered_and_running_checkpoints", "accepted_running_terminal_action").include?("taken atomically at acceptance") &&
    rebase.dig("offered_and_running_checkpoints", "merged_component_action").include?("remain in scope"),
  "offered, accepted-running, and merged-component snapshot checkpoints must remain distinct",
)
%w[
  clock_cycle_id
  opportunity_id
  global_state_id
  coordinator_generation
  opportunity_projection_epoch_id
  action_id
  decision_id
  device_id
  session_id
].each do |identity|
  assert(runtime.fetch("identities").key?(identity), "missing #{identity} contract")
end

root = Pathname.new(protocol_path).dirname.parent.parent.parent
product_model = root.join("design/PRODUCT_MODEL.md").read
interaction = root.join("design/INTERACTION_SPEC.md").read
screens = root.join("design/SCREEN_INVENTORY.md").read
copy = root.join("design/COPY_INVENTORY.md").read
accessibility = root.join("design/ACCESSIBILITY.md").read
health = root.join("research/health/03_PRODUCT_HEALTH_PROTOCOL_SPEC.md").read
decisions = root.join("design/DECISIONS.md").read
conformance = root.join("design/CURRENT_STATE_CONFORMANCE.md").read
flows = root.join("design/USER_FLOWS.md").read
authority = root.join("design/AUTHORITY.md").read
privacy = root.join("research/health/07_PRIVACY_AND_DATA_SPEC.md").read
assert(product_model.include?("Exhaustive fresh-cycle effects"), "PRODUCT_MODEL fresh-cycle table must declare its scope")
%w[snooze skip capsule position recovery merged].each do |variant|
  assert(product_model.downcase.include?(variant), "PRODUCT_MODEL fresh-cycle table is missing #{variant}")
end
assert(!interaction.include?("greatest recorded remaining milliseconds"), "prose still ranks terminal actions by remaining duration")
assert(!interaction.include?("wall deadline reconstructs remaining"), "prose still reconstructs accepted deadlines from wall time")
[
  "Calm",
  "Balanced",
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
assert(!screens.include?("Two minutes instead"), "running movement must not advertise a nonexistent duration-switch control")
assert(
  screens.include?('Merged offered additionally announces "Just the visual one, V."') &&
    accessibility.include?('Merged offered additionally names "Just the visual one, V."'),
  "merged visual-only a11y copy is missing from a governing surface",
)
assert(
  !accessibility.include?('BR-05\'s "Start 5 minutes" initial focus no longer exists') &&
    accessibility.include?("Movement is different") &&
    accessibility.include?("Timer not started"),
  "ACCESSIBILITY movement offered/running contract remains stale",
)
assert(
  interaction.include?("operational-only `timerRecoveryUnavailable`") &&
    health.include?("operational-only") && health.include?("`timerRecoveryUnavailable`") &&
    decisions.include?("D-033 contract-repair addendum") &&
    conformance.include?("unknown-timer operational recovery"),
  "unknown timer recovery is not reconciled across governing prose",
)
assert(
  interaction.include?("Movement `Now` opens its offered field") &&
    copy.include?("standalone movement opens the offered field and records no product fact yet"),
  "breakStarted copy/event ownership is inconsistent",
)
assert(
  authority.include?("operational-only `timerRecoveryUnavailable`") &&
    authority.include?("sign/fence the old projection epoch") &&
    authority.include?("1–3/Q/A/P/**V**") &&
    accessibility.include?("three equal-rank content choices") &&
    !accessibility.include?("four options stack vertically"),
  "AUTHORITY/accessibility trace cleanup drifted",
)
[
  "Ready on this device",
  "Device offline. Keep using this Mac.",
  "Session expired. Reconnect to continue.",
  "Sending timer…",
  "Reconnecting…",
  "That action no longer applies. No change was recorded.",
  "Ended on another device.",
  "Couldn’t transfer. The timer is still running on this Mac.",
].each do |phrase|
  assert(copy.include?(phrase) && screens.include?(phrase.split(".").first), "companion copy/screen state missing #{phrase}")
end
assert(
  expected_companion_states.all? { |state| accessibility.include?(state.tr("_", "-")) } &&
    flows.include?("old generation / fenced projection → Rejected, no-op") &&
    interaction.include?("matching generation") && interaction.include?("projection epoch") &&
    interaction.include?("opportunity revision") && interaction.include?("segment"),
  "companion UX/a11y flow is not reconciled across governing documents",
)
[
  "Timer couldn’t be restored",
  "No finish was recorded. This schedule is still due.",
  "Still due · timer not restored",
].each do |phrase|
  assert(
    [copy, screens, interaction].all? { |document| document.gsub(/\s+/, " ").include?(phrase) },
    "timer recovery copy missing #{phrase}",
  )
end
assert(
  privacy.gsub(/\s+/, " ").include?("**90 seconds**") &&
    privacy.gsub(/\s+/, " ").include?("no durable record identity") &&
    privacy.gsub(/\s+/, " ").include?("never enter an") &&
    privacy.gsub(/\s+/, " ").include?("Delete history") &&
    privacy.gsub(/\s+/, " ").include?("Reset app data") &&
    copy.include?("Temporary action buffers") &&
    conformance.include?("Class-0 ≤90 s memory-only candidate disposal"),
  "candidate privacy lifecycle is incomplete across privacy/copy/conformance",
)
assert(
  product_model.include?("visual time accrued before that movement cannot cause a prompt") &&
    health.include?("Visual time accrued before that likely-away interval cannot cause a") &&
    product_model.include?("A genuinely new") &&
    health.include?("new fresh or Custom visual cycle"),
  "trust guarantee must apply to pre-movement/pre-away accrual without banning new cycles",
)
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
