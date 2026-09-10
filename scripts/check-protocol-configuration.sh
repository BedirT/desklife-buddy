#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"
cd "$ROOT"

input="$ROOT/research/health/machine-readable/product_protocol.yaml"
runtime_contract="$ROOT/design/machine-readable/timing_runtime_v2.yaml"
event_schema="$ROOT/research/health/machine-readable/event_schema.json"
runtime="$ROOT/design/machine-readable/timing_runtime_v2.yaml"
generated="$ROOT/App/Protocol/GeneratedProtocolProfiles.swift"
temporary="$(/usr/bin/mktemp -t protocol-profiles).swift"
trap '/bin/rm -f "$temporary"' EXIT

/usr/bin/ruby "$ROOT/scripts/support/generate_protocol_configuration.rb" "$input" "$runtime" "$temporary"
mise_exec swiftformat "$temporary" --config "$ROOT/.swiftformat" --cache ignore >/dev/null

if ! /usr/bin/cmp -s "$temporary" "$generated"; then
  echo "Generated protocol profiles are stale. Run scripts/generate-protocol-configuration.sh." >&2
  /usr/bin/diff -u "$generated" "$temporary" || true
  exit 1
fi

/usr/bin/ruby - "$input" "$runtime_contract" "$event_schema" <<'RUBY'
require "date"
require "digest"
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
assert(runtime.dig("meta", "decision") == "D-043", "timing runtime must cite D-043")
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
custom_storage = custom_v2.fetch("storage_compatibility_domain")
custom_authoring = custom_v2.fetch("new_authoring_constraints")
custom_edit = custom_v2.fetch("edit_semantics")
custom_metadata = custom_v2.fetch("migration_metadata_contract")
def valid_custom_metadata?(metadata)
  metadata.dig("preset_contract_version", "type") == "unsigned_integer" &&
    metadata.dig("preset_contract_version", "required_value") == 2 &&
    metadata.dig("preset_identifier", "type") == "stable_ascii_identifier" &&
    metadata.dig("preset_identifier", "required_value") == "custom_v2" &&
    metadata.dig("migration_state", "type") == "registered_enum" &&
    metadata.dig("migration_state", "allowed_values") == %w[v2_selected v2_migrated_with_explicit_acceptance] &&
    metadata.fetch("custom_timing_required") == true &&
    metadata.fetch("unknown_metadata") == "rejected_before_save"
end
assert(
  custom_v2.fetch("payload_schema_version") == 2 &&
    custom_storage.fetch("numeric_values").include?("every_positive_finite_v1_value") &&
    custom_storage.fetch("migration_rule").include?("never_silently_retune_reject_or_coerce") &&
    custom_authoring.fetch("visual_duration_range_seconds") == [10, 60] &&
    custom_authoring.fetch("movement_duration_options_seconds") == [120, 300] &&
    custom_authoring.fetch("applies_to").include?("newly_created_or_user_edited") &&
    custom_edit.fetch("scalar_dirty_paths") == %w[visual.softDueSeconds visual.targetSeconds visual.latestPreferredSeconds movement.softDueSeconds movement.targetSeconds movement.latestPreferredSeconds] &&
    custom_edit.fetch("atomic_group_dirty_paths") == %w[visual.durationOptionsSeconds movement.durationOptionsSeconds] &&
    custom_edit.fetch("validation_rule").include?("only to dirty scalar fields") &&
    custom_edit.fetch("validation_rule").include?("minimum necessary") &&
    custom_edit.fetch("untouched_rule").include?("legacy visual 5 seconds or movement [30]") &&
    valid_custom_metadata?(custom_metadata),
  "custom_v2 must separate legacy-compatible storage from safer new-authoring bounds",
)
legacy_custom = protocol.dig("preset_contract_v2", "legacy_identifier_disposition", "custom")
legacy_schema = protocol.dig("preset_contract_v2", "legacy_custom_v1_payload_schema")
extreme_custom = protocol.dig("preset_contract_v2", "legacy_custom_extreme_fixture")
expected_legacy_fields = [
  {"name" => "softDueSeconds", "type" => "finite_binary64_seconds"},
  {"name" => "targetSeconds", "type" => "finite_binary64_seconds"},
  {"name" => "latestPreferredSeconds", "type" => "finite_binary64_seconds"},
  {"name" => "durationOptionsSeconds", "type" => "nonempty_ordered_array_of_finite_binary64_seconds"},
]
expected_extreme_timing = {
  "visual" => {
    "softDueSeconds" => 5,
    "targetSeconds" => 5,
    "latestPreferredSeconds" => 5,
    "durationOptionsSeconds" => [5, 7],
  },
  "movement" => {
    "softDueSeconds" => 30,
    "targetSeconds" => 60,
    "latestPreferredSeconds" => 90,
    "durationOptionsSeconds" => [30, 300, 45],
  },
}
def valid_legacy_custom_schema?(schema, expected_fields)
  expected_constraints = %w[
    every_scalar_and_duration_array_element_is_finite_and_strictly_greater_than_zero
    softDueSeconds_less_than_or_equal_to_targetSeconds
    targetSeconds_less_than_or_equal_to_latestPreferredSeconds
    durationOptionsSeconds_is_nonempty
    durationOptionsSeconds_element_order_is_significant_and_is_never_sorted_or_deduplicated
  ]
  schema.fetch("object_member_wire_order") == "not_semantically_significant_for_keyed_Codable_containers" &&
    schema.fetch("canonical_schema_traversal_order") == "exactly_the_ordered_fields_lists_below" &&
    schema.fetch("ordered_fields") == [
    {"name" => "kind", "type" => "utf8_string", "required_value" => "custom"},
    {"name" => "customTiming", "type" => "custom_protocol_timing_v1"},
  ] &&
    schema.dig("custom_protocol_timing_v1", "ordered_fields") == [
      {"name" => "visual", "type" => "opportunity_timing_v1"},
      {"name" => "movement", "type" => "opportunity_timing_v1"},
    ] &&
    schema.dig("opportunity_timing_v1", "ordered_fields") == expected_fields &&
    schema.dig("opportunity_timing_v1", "constraints") == expected_constraints &&
    schema.fetch("additional_persisted_fields") == "none"
end
assert(
  legacy_custom.fetch("suggested_successor") == "custom_v2" &&
    legacy_custom.fetch("payload_compatibility").include?("every legal positive finite v1") &&
    legacy_custom.fetch("payload_compatibility").include?("does not reinterpret") &&
    legacy_custom.fetch("extreme_payload_fixture") == "legacy_custom_extreme_fixture" &&
    valid_legacy_custom_schema?(legacy_schema, expected_legacy_fields) &&
    extreme_custom.dig("legacy_payload", "kind") == "custom" &&
    extreme_custom.dig("legacy_payload", "customTiming") == expected_extreme_timing &&
    extreme_custom.dig("migrated_representation", "customTiming") == expected_extreme_timing &&
    extreme_custom.fetch("allowed_difference").include?("only_selection_metadata") &&
    extreme_custom.fetch("allowed_difference").include?("legacy_kind_custom_is_replaced"),
  "legacy custom migration must preserve every persisted field and both ordered duration arrays",
)
legacy_field_mutation = Marshal.load(Marshal.dump(legacy_schema))
legacy_field_mutation["opportunity_timing_v1"]["ordered_fields"].delete_at(2)
assert(!valid_legacy_custom_schema?(legacy_field_mutation, expected_legacy_fields), "deleting one legacy Custom field must fail schema parity")
legacy_constraint_mutations = %w[
  every_scalar_and_duration_array_element_is_finite_and_strictly_greater_than_zero
  softDueSeconds_less_than_or_equal_to_targetSeconds
  targetSeconds_less_than_or_equal_to_latestPreferredSeconds
  durationOptionsSeconds_is_nonempty
].map do |constraint|
  mutation = Marshal.load(Marshal.dump(legacy_schema))
  mutation["opportunity_timing_v1"]["constraints"].delete(constraint)
  mutation
end
metadata_mutation = Marshal.load(Marshal.dump(custom_metadata))
metadata_mutation["preset_identifier"]["required_value"] = "custom"
assert(
  legacy_constraint_mutations.none? { |mutation| valid_legacy_custom_schema?(mutation, expected_legacy_fields) } &&
    !valid_custom_metadata?(metadata_mutation),
  "Custom positivity/finite/window/nonempty and migration ID metadata mutations must fail",
)
unrelated_edit_projection = Marshal.load(Marshal.dump(expected_extreme_timing))
unrelated_edit_projection["movement"]["targetSeconds"] = 61
assert(
  unrelated_edit_projection.dig("visual", "durationOptionsSeconds") == [5, 7] &&
    unrelated_edit_projection.dig("movement", "durationOptionsSeconds") == [30, 300, 45] &&
    unrelated_edit_projection.dig("visual", "softDueSeconds") == 5,
  "editing one Custom scalar must preserve every untouched out-of-authoring-bound legacy field and duration group",
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
derived_cross_slot_ids = guards.select do |_id, guard|
  guard.fetch("source_phases").include?("merged_visual_running") && guard.fetch("target_phase") != "unchanged"
end.keys.sort
assert(
  cross_slot &&
    cross_slot.fetch("coverage_selector").include?("Derive every concrete transition") &&
    cross_slot.fetch("requires_same_origin") == %w[opportunity_id coordinator_generation opportunity_revision visual_segment_id] &&
    cross_slot.fetch("winner_rank_smallest_wins") == {
      "merged.escape_during_visual" => 0,
      "merged.visual_segment_done_early" => 10,
      "system.timer_recovery_unavailable_merged_visual" => 15,
      "merged.visual_segment_finished" => 20,
    } &&
    cross_slot.fetch("loser_effect") == "operational_rejected_no_op_no_fact_no_clock_effect" &&
    cross_slot.fetch("already_committed_component_rule").include?("merged.escape_during_movement"),
  "merged visual completion and same-revision parent Escape need one cross-slot arbiter",
)
assert(
  resolver_groups.fetch("merged_visual_cross_slot_candidate_set").sort == derived_cross_slot_ids &&
    cross_slot.fetch("winner_rank_smallest_wins").keys.sort == derived_cross_slot_ids &&
    cross_slot.fetch("component_finality").include?("create no timerFinished") &&
    cross_slot.fetch("component_finality").include?("emit no product fact or fresh cycle") &&
    cross_slot.fetch("convergence").include?("both timerFinished and skipped") &&
    cross_slot.fetch("convergence").include?("Arrival time and wall time are not inputs") &&
    guards.fetch("merged.escape_during_visual").fetch("required_payload").include?("coordinator_generation") &&
    derived_cross_slot_ids.all? { |id| guards.fetch(id).fetch("source_phases") == ["merged_visual_running"] } &&
    transition_by_id.fetch("system.timer_recovery_unavailable_merged_visual").fetch("facts").empty? &&
    transition_by_id.fetch("system.timer_recovery_unavailable_merged_visual").dig("clocks", "visual") == "retain" &&
    %w[merged.visual_segment_finished merged.visual_segment_done_early merged.escape_during_visual].all? { |id| transition_by_id.fetch(id).dig("clocks", "visual") == "fresh_cycle" },
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
merged_timer_recovery = transition_by_id.fetch("system.timer_recovery_unavailable_merged_visual")
assert(
  timer_recovery.fetch("facts").empty? &&
    merged_timer_recovery.fetch("facts").empty? &&
    timer_recovery.fetch("ledgers") == ["operational"] &&
    merged_timer_recovery.fetch("ledgers") == ["operational"] &&
    timer_recovery.fetch("clocks").values.all? { |effect| effect == "retain" } &&
    deadline.dig("recovery_unavailable", "grace_seconds") == 60 &&
    deadline.dig("recovery_unavailable", "product_facts") == [] &&
    deadline.dig("recovery_unavailable", "grace_begins") == "after_signed_fence_and_operational_disposition_commit" &&
    timer_recovery.fetch("recovery").include?("commit_signed_projection_fence"),
  "unknown timer recovery must remain operational-only and preserve every due schedule",
)
assert(
  guards.fetch("system.timer_recovery_unavailable").fetch("source_phases").sort ==
    %w[merged_movement_running movement_running recovery_running visual_running] &&
    guards.fetch("system.timer_recovery_unavailable_merged_visual").fetch("source_phases") == ["merged_visual_running"] &&
    guards.fetch("system.timer_recovery_unavailable").fetch("required_payload").include?("unavailable_epoch_or_anchor_reason") &&
    guards.fetch("system.timer_recovery_unavailable").fetch("required_payload").include?("retained_schedule_phase") &&
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
protocol_sender_outbox = protocol.dig("candidate_data_lifecycle_v2", "sender_crash_replay_outbox")
protocol_outcome_pending = protocol.dig("candidate_data_lifecycle_v2", "outcome_ack_pending")
assert(
  candidate_lifecycle.fetch("class") == "class_0_ephemeral_operational_state" &&
    candidate_lifecycle.fetch("location") == "memory_only" &&
    candidate_lifecycle.fetch("maximum_retention_seconds") <= 120 &&
    candidate_lifecycle.fetch("maximum_retention_seconds") == 90 &&
    candidate_lifecycle.fetch("export") == "never" &&
    candidate_lifecycle.fetch("persistence") == "prohibited" &&
    candidate_lifecycle.fetch("stable_record_identity") == "none" &&
    candidate_lifecycle.dig("compact_replay_receipt", "maximum_retention_seconds") == 90 &&
    candidate_lifecycle.dig("compact_replay_receipt", "discard_when").include?("acknowledgement_of_ack") &&
    candidate_lifecycle.dig("compact_replay_receipt", "never_discard_for").include?("projection_revision_fence") &&
    candidate_lifecycle.dig("compact_replay_receipt", "prohibited").include?("raw_payload") &&
    protocol.dig("candidate_data_lifecycle_v2", "maximum_retention_seconds") == 90 &&
    protocol.dig("candidate_data_lifecycle_v2", "persistence") == "false_except_sender_crash_replay_outbox_and_outcome_ack_pending" &&
    protocol.dig("candidate_data_lifecycle_v2", "compact_replay_receipt", "raw_payload") == false &&
    protocol.dig("candidate_data_lifecycle_v2", "compact_replay_receipt", "projection_or_generation_fence_does_not_erase") == true &&
    protocol_sender_outbox.fetch("maximum_retention_seconds") == 90 &&
    protocol_sender_outbox.fetch("replay_gate").include?("strictly_less_than_90") &&
    protocol_sender_outbox.fetch("epoch_mismatch").include?("erase_without_resend_without_replacement") &&
    protocol_sender_outbox.fetch("sole_raw_action_envelope_persistence_exception") == true &&
    protocol_sender_outbox.fetch("excluded_from") == %w[backup history export analytics logs product_facts health_records] &&
    protocol_outcome_pending.fetch("maximum_retention_seconds", 90) == 90 &&
    protocol_outcome_pending.fetch("raw_payload") == false &&
    protocol_outcome_pending.fetch("replay_gate").include?("same_local_monotonic_epoch") &&
    protocol_outcome_pending.fetch("fields").include?("exact_complete_signed_outcome_ack_bytes_v1"),
  "received raw candidates must remain memory-only while bounded sender/outcome crash transport records stay disclosed and unexported",
)
companion = runtime.fetch("companion_contract")
companion_registry = companion.fetch("state_registry")
control_catalog = companion_registry.fetch("control_catalog")
companion_states = companion_registry.fetch("states")
expected_companion_states = %w[live offline offline_terminal_ack_unknown offline_nonterminal_ack_unknown expired transfer_pending terminal_action_pending nonterminal_action_pending revalidating revalidating_terminal_ack_unknown revalidating_nonterminal_ack_unknown rejected_no_op already_ended transfer_failed]
assert(companion_states.keys == expected_companion_states, "companion state registry is incomplete or reordered")
expected_companion_states.each do |state|
  projection = companion_states.fetch(state)
  %w[control_ids enabled_rule focus_target focus_order keyboard cancellation].each do |field|
    assert(projection.key?(field), "companion #{state} is missing #{field}")
  end
  assert(projection.key?("visible_status") || projection.key?("visible_status_template"), "companion #{state} lacks visible copy")
  assert(projection.key?("voiceover_announcement") || projection.key?("voiceover_template"), "companion #{state} lacks VoiceOver copy")
  assert(projection.fetch("control_ids").all? { |id| control_catalog.key?(id) }, "companion #{state} references an unknown control")
  assert(projection.fetch("focus_order") == projection.fetch("control_ids"), "companion #{state} focus order must match available controls")
  unless state == "live"
    assert(projection.fetch("control_ids").include?(projection.fetch("focus_target")), "companion #{state} focuses an unavailable control")
  end
end
assert(
  companion_states.dig("live", "control_ids").include?("take_with_me") &&
    companion_states.dig("offline", "control_ids") == %w[retry close] &&
    companion_states.dig("offline_terminal_ack_unknown", "control_ids") == %w[check_status close] &&
    companion_states.dig("offline_nonterminal_ack_unknown", "control_ids") == %w[check_status close] &&
    companion_states.dig("offline_nonterminal_ack_unknown", "visible_status_template").include?("started") &&
    companion_states.dig("offline_terminal_ack_unknown", "visible_status_template").include?("do not repeat") &&
    companion_states.dig("offline_terminal_ack_unknown", "preserved_provenance").include?("selected_action_id") &&
    companion_states.dig("expired", "control_ids") == %w[retry close] &&
    companion_states.dig("transfer_failed", "control_ids") == %w[retry close] &&
    companion_states.dig("terminal_action_pending", "visible_status_template").include?("selected_action_label") &&
    companion_states.dig("nonterminal_action_pending", "visible_status_template").include?("selected_action_label") &&
    companion_states.dig("nonterminal_action_pending", "preserved_provenance").include?("expected_running_target_phase") &&
    companion_states.dig("revalidating_terminal_ack_unknown", "voiceover_template").include?("Do not repeat") &&
    companion_states.dig("revalidating_nonterminal_ack_unknown", "voiceover_template").include?("Do not repeat") &&
    !companion_states.dig("terminal_action_pending", "visible_status_template").include?("Sending timer") &&
    companion_states.dig("live", "focus_target") == "exact_selected_live_phase_registry_row_focus_target" &&
    companion_registry.fetch("parity_rule").include?("no disabled trigger receives focus") &&
    companion.fetch("live_scope_rule").include?("coordinator generation") &&
    companion.fetch("sensor_free_fallback").include?("without HealthKit, motion, location, camera"),
  "companion controls must be live-generation gated, explicit, accessible, and sensor-free",
)
receiver_keys = companion.fetch("receiver_and_key_contract")
rotation = receiver_keys.fetch("rotation_lifecycle")
assert(
  receiver_keys.fetch("handoff_request_requires").include?("receiver_key_id_fixed_32_raw_bytes") &&
    receiver_keys.fetch("handoff_request_requires").include?("receiver_key_epoch_unsigned_uint64") &&
    rotation.fetch("envelope_binding") == "every_action_outcome_ack_ack_of_ack_handoff_and_projection_fence_names_key_id_and_key_epoch" &&
    rotation.fetch("old_key_retention").include?("old_public_verification_key") &&
    rotation.fetch("old_key_retention").include?("nonexportable_old_private_signing_key_handle") &&
    rotation.fetch("pending_old_private_key_rule").include?("encrypted_keychain_nonexportable_handle_only") &&
    rotation.fetch("pending_old_private_key_rule").include?("erase_with_the_bound_pending_record") &&
    rotation.fetch("new_pairing_replaces_peer").include?("immediately_fence_the_old_peer_generation"),
  "receiver and key rotation must bind exact epochs without stranding a pending acknowledgement",
)
rotation_mutation = Marshal.load(Marshal.dump(rotation))
rotation_mutation.delete("pending_old_private_key_rule")
assert(rotation_mutation != rotation, "deleting pending old-key lifecycle must fail")

normalization = runtime.dig("action_contract", "companion_action_normalization")
remote_registry = normalization.fetch("remote_to_concrete_transition")
operational_wrappers = normalization.fetch("nonterminal_operational_wrappers")
expected_remote_registry = {
  "companion.take_with_me_request" => "companion.take_with_me",
  "companion.visual.done_early" => "visual.done_early",
  "companion.visual.skip" => "visual.skip",
  "companion.movement.done_early" => "movement.done_early",
  "companion.movement.already_moved" => "movement.already_moved",
  "companion.movement.position_changed_offered" => "movement.position_changed_offered",
  "companion.movement.position_changed_running" => "movement.position_changed_running",
  "companion.movement.skip_offered" => "movement.skip_offered",
  "companion.movement.skip_running" => "movement.skip_running",
  "companion.position.changed" => "position.changed",
  "companion.position.skip" => "position.skip",
  "companion.recovery.done_early" => "recovery.done_early",
  "companion.recovery.skip_offered" => "recovery.skip_offered",
  "companion.recovery.skip_running" => "recovery.skip_running",
  "companion.merged.visual_done_early" => "merged.visual_segment_done_early",
  "companion.merged.movement_start_5" => "merged.movement_accept",
  "companion.merged.movement_start_2" => "merged.movement_accept",
  "companion.merged.movement_done_early" => "merged.movement_done_early",
  "companion.merged.movement_already_moved" => "merged.movement_already_moved",
  "companion.merged.movement_position_changed" => "merged.movement_position_changed",
  "companion.merged.movement_skip" => "merged.movement_skip",
  "companion.merged.visual_only" => "merged.visual_only",
  "companion.merged.skip_during_visual" => "merged.escape_during_visual",
}
def valid_remote_registry?(registry, transition_by_id, resolved_ids, operational_wrappers)
  registry.all? do |remote_id, target|
    transition = transition_by_id[target]
    next false unless transition && resolved_ids.count(target) == 1
    if operational_wrappers.key?(remote_id)
      exception = operational_wrappers.fetch(remote_id)
      base = target == exception.fetch("required_target") &&
        transition.fetch("facts") == exception.fetch("required_facts") &&
        transition.fetch("ledgers") == exception.fetch("required_ledgers") &&
        transition.fetch("terminal") == false &&
        exception.fetch("resolver_class") == "authoritative_opportunity_nonterminal"
      if exception.fetch("product_fact") == "prohibited"
        base && transition.fetch("facts").empty?
      else
        base && exception.fetch("product_fact") == "required_once_after_signed_outcome" &&
          transition.fetch("facts") == ["breakStarted"]
      end
    else
      !transition.fetch("facts").empty?
    end
  end
end
assert(
  normalization.fetch("registry_closed") == true &&
    remote_registry == expected_remote_registry &&
    !transition_by_id.key?("companion.terminal_action") &&
    valid_remote_registry?(remote_registry, transition_by_id, resolved_ids, operational_wrappers) &&
    remote_registry.fetch("companion.take_with_me_request") == "companion.take_with_me" &&
    operational_wrappers.keys == %w[companion.take_with_me_request companion.merged.movement_start_5 companion.merged.movement_start_2] &&
    remote_registry.fetch("companion.merged.visual_done_early") == "merged.visual_segment_done_early" &&
    guards.fetch(remote_registry.fetch("companion.merged.visual_done_early")).fetch("target_phase") == "merged_movement_offered",
  "companion wrappers must materialize exact local transitions before validation",
)
no_product_fact_mutation = remote_registry.merge("companion.visual.done_early" => "system.timer_recovery_unavailable")
assert(
  !valid_remote_registry?(no_product_fact_mutation, transition_by_id, resolved_ids, operational_wrappers),
  "companion registry mutation to a no-product-fact transition must fail",
)
action_groups = companion_registry.fetch("action_groups_closed_remote_ids")
live_phases = companion_registry.fetch("live_phase_registry")
expected_action_groups = {
  "take_with_me" => %w[companion.take_with_me_request],
  "start_5_minutes" => %w[companion.merged.movement_start_5],
  "start_2_minutes" => %w[companion.merged.movement_start_2],
  "done_early" => %w[companion.visual.done_early companion.movement.done_early companion.recovery.done_early companion.merged.visual_done_early companion.merged.movement_done_early],
  "already_moved" => %w[companion.movement.already_moved companion.merged.movement_already_moved],
  "change_position" => %w[companion.movement.position_changed_offered companion.movement.position_changed_running companion.position.changed companion.merged.movement_position_changed],
  "visual_only" => %w[companion.merged.visual_only],
  "skip" => %w[companion.visual.skip companion.movement.skip_offered companion.movement.skip_running companion.position.skip companion.recovery.skip_offered companion.recovery.skip_running companion.merged.skip_during_visual companion.merged.movement_skip],
}
expected_live_phases = %w[visual_offered visual_running movement_offered movement_running position_offered recovery_offered recovery_running merged_visual_running merged_movement_offered merged_movement_running]
expected_live_phase_controls = {
  "visual_offered" => %w[skip],
  "visual_running" => %w[take_with_me done_early skip],
  "movement_offered" => %w[already_moved change_position skip],
  "movement_running" => %w[take_with_me done_early already_moved change_position skip],
  "position_offered" => %w[change_position skip],
  "recovery_offered" => %w[skip],
  "recovery_running" => %w[take_with_me done_early skip],
  "merged_visual_running" => %w[take_with_me done_early skip],
  "merged_movement_offered" => %w[start_5_minutes start_2_minutes already_moved change_position visual_only skip],
  "merged_movement_running" => %w[take_with_me done_early already_moved change_position skip],
}
def valid_live_phase_registry?(live_phases, expected_phases, expected_controls, controls, action_groups, remote_registry)
  return false unless live_phases.keys == expected_phases
  live_phases.all? do |phase, row|
    row.fetch("control_ids") == expected_controls.fetch(phase) &&
      row.fetch("control_ids") == row.fetch("focus_order") &&
      row.fetch("control_ids").include?(row.fetch("focus_target")) &&
      row.fetch("control_remote_actions").keys == row.fetch("control_ids") &&
      row.fetch("control_ids").all? { |id| controls.key?(id) } &&
      row.fetch("control_remote_actions").all? do |control_id, action_id|
        group = controls.fetch(control_id).fetch("action_group")
        action_groups.fetch(group).include?(action_id) && remote_registry.key?(action_id)
      end &&
      row.fetch("escape_behavior") == "dismiss_companion_projection_only" &&
      !row.key?("escape_remote_action_id") &&
      (phase == "merged_movement_offered") == row.fetch("control_ids").include?("visual_only")
  end
end
assert(action_groups == expected_action_groups, "companion action groups must equal the closed required remote-ID registry")
assert(
  valid_live_phase_registry?(live_phases, expected_live_phases, expected_live_phase_controls, control_catalog, action_groups, remote_registry),
  "companion live controls/focus/actions must be exact for every phase and segment",
)
covered_remote_ids = action_groups.values.flatten.uniq.sort
assert(
  covered_remote_ids == remote_registry.keys.sort,
  "phase controls/action groups must exhaustively cover every normalized remote action ID",
)
deleted_visual_skip_groups = Marshal.load(Marshal.dump(action_groups))
deleted_visual_skip_groups["skip"].delete("companion.visual.skip")
assert(
  deleted_visual_skip_groups != expected_action_groups,
  "deleting companion.visual.skip from the required action group must fail parity",
)
merged_offer = live_phases.fetch("merged_movement_offered")
remote_payloads = normalization.fetch("remote_payload_constraints")
assert(
  merged_offer.fetch("control_ids") == %w[start_5_minutes start_2_minutes already_moved change_position visual_only skip] &&
    merged_offer.fetch("focus_target") == "start_5_minutes" &&
    merged_offer.fetch("shortcuts", {}).fetch("start_5_minutes") == %w[return 5] &&
    merged_offer.fetch("shortcuts", {}).fetch("start_2_minutes") == %w[q 2] &&
    merged_offer.fetch("control_remote_actions").values_at("start_5_minutes", "start_2_minutes") ==
      %w[companion.merged.movement_start_5 companion.merged.movement_start_2] &&
    remote_payloads.dig("companion.merged.movement_start_5", "selected_duration_seconds_300_or_120") == 300 &&
    remote_payloads.dig("companion.merged.movement_start_2", "selected_duration_seconds_300_or_120") == 120,
  "merged companion movement offer must expose the complete first-frame choice set",
)
assert(
  companion_states.values.all? { |state| state.dig("keyboard", "escape_command_period") == "dismiss_status_only" } &&
    live_phases.values.all? { |row| row.fetch("escape_behavior") == "dismiss_companion_projection_only" },
  "Escape and Command-period must dismiss companion status only",
)
companion_operational = companion_registry.fetch("operational_state_transitions")
companion_provenance = companion_registry.fetch("action_ack_provenance_lifecycle")
assert(
  companion_operational.dig("every_state.escape_or_command_period", "target") == "dismiss_projection_only" &&
    companion_operational.dig("every_state.escape_or_command_period", "remote_action") == "none" &&
    companion_operational.dig("offline_terminal_ack_unknown.check_status", "resend_selected_action") == false &&
    companion_operational.dig("offline_nonterminal_ack_unknown.check_status", "resend_selected_action") == false &&
    companion_operational.dig("live.nonterminal_action", "target") == "nonterminal_action_pending" &&
    companion_operational.dig("nonterminal_action_pending.outcome_ack", "target") == "merged_movement_running_or_rejected_no_op" &&
    companion_operational.dig("revalidating_nonterminal_ack_unknown.known_outcome", "target") == "merged_movement_running_or_rejected_no_op" &&
    companion_operational.dig("revalidating_terminal_ack_unknown.cancel_revalidation", "resend_selected_action") == false &&
    companion_provenance.fetch("maximum_retention_seconds") == 90 &&
    companion_provenance.fetch("discard_at").include?("valid_signed_acknowledgement_of_ack") &&
    companion_provenance.fetch("applies_to").include?("nonterminal_action_pending") &&
    companion_provenance.fetch("prohibited").include?("automatic_resend_from_status_check"),
  "offline/revalidating companion transitions must preserve bounded terminal and nonterminal provenance without resend",
)

def valid_remote_semantics?(live_phases, remote_registry, expected_registry, guards, transition_by_id, resolver_groups)
  expected_target_phase = {
    "companion.take_with_me" => "unchanged",
    "visual.done_early" => "terminal_provisional", "visual.skip" => "terminal_provisional",
    "movement.done_early" => "terminal_provisional", "movement.already_moved" => "terminal_provisional",
    "movement.position_changed_offered" => "terminal_provisional", "movement.position_changed_running" => "terminal_provisional",
    "movement.skip_offered" => "terminal_provisional", "movement.skip_running" => "terminal_provisional",
    "position.changed" => "terminal_provisional", "position.skip" => "terminal_provisional",
    "recovery.done_early" => "terminal_provisional", "recovery.skip_offered" => "terminal_provisional", "recovery.skip_running" => "terminal_provisional",
    "merged.visual_segment_done_early" => "merged_movement_offered", "merged.movement_accept" => "merged_movement_running",
    "merged.movement_done_early" => "terminal_provisional", "merged.movement_already_moved" => "terminal_provisional",
    "merged.movement_position_changed" => "terminal_provisional", "merged.movement_skip" => "terminal_provisional",
    "merged.visual_only" => "terminal_provisional", "merged.escape_during_visual" => "terminal_provisional",
  }
  expected_facts = {
    "companion.take_with_me" => [],
    "visual.done_early" => %w[userDeclaredCompleted], "visual.skip" => %w[skipped],
    "movement.done_early" => %w[userDeclaredCompleted], "movement.already_moved" => %w[userDeclaredAlreadyMoved],
    "movement.position_changed_offered" => %w[positionChanged], "movement.position_changed_running" => %w[positionChanged],
    "movement.skip_offered" => %w[skipped], "movement.skip_running" => %w[skipped],
    "position.changed" => %w[positionChanged], "position.skip" => %w[skipped],
    "recovery.done_early" => %w[userDeclaredCompleted], "recovery.skip_offered" => %w[skipped], "recovery.skip_running" => %w[skipped],
    "merged.visual_segment_done_early" => %w[userDeclaredCompleted], "merged.movement_accept" => %w[breakStarted],
    "merged.movement_done_early" => %w[userDeclaredCompleted], "merged.movement_already_moved" => %w[userDeclaredAlreadyMoved],
    "merged.movement_position_changed" => %w[positionChanged], "merged.movement_skip" => %w[skipped],
    "merged.visual_only" => %w[skipped], "merged.escape_during_visual" => %w[skipped],
  }
  expected_clocks = {
    "companion.take_with_me" => {"visual" => "retain", "movement" => "retain", "position" => "retain", "recovery" => "retain"},
    "visual.done_early" => {"visual" => "fresh_cycle", "movement" => "unchanged", "position" => "unchanged", "recovery" => "unchanged"},
    "visual.skip" => {"visual" => "fresh_cycle", "movement" => "unchanged", "position" => "unchanged", "recovery" => "unchanged"},
    "movement.done_early" => {"visual" => "fresh_cycle", "movement" => "fresh_cycle", "position" => "retain", "recovery" => "fresh_cycle"},
    "movement.already_moved" => {"visual" => "fresh_if_screen_away_basis", "movement" => "fresh_cycle", "position" => "retain", "recovery" => "fresh_cycle"},
    "movement.position_changed_offered" => {"visual" => "retain", "movement" => "retain", "position" => "rotate_position_cycle_preserving_enablement", "recovery" => "retain"},
    "movement.position_changed_running" => {"visual" => "restore_pre_ritual", "movement" => "retain", "position" => "rotate_position_cycle_preserving_enablement", "recovery" => "retain"},
    "movement.skip_offered" => {"visual" => "retain", "movement" => "fresh_cycle", "position" => "retain", "recovery" => "deferral_increment"},
    "movement.skip_running" => {"visual" => "restore_pre_ritual", "movement" => "fresh_cycle", "position" => "retain", "recovery" => "deferral_increment"},
    "position.changed" => {"visual" => "retain", "movement" => "retain", "position" => "rotate_position_cycle_preserving_enablement", "recovery" => "retain"},
    "position.skip" => {"visual" => "retain", "movement" => "retain", "position" => "rotate_position_cycle_preserving_enablement", "recovery" => "retain"},
    "recovery.done_early" => {"visual" => "fresh_cycle", "movement" => "fresh_cycle", "position" => "retain", "recovery" => "fresh_cycle"},
    "recovery.skip_offered" => {"visual" => "retain", "movement" => "retain", "position" => "retain", "recovery" => "fresh_cycle"},
    "recovery.skip_running" => {"visual" => "restore_pre_ritual", "movement" => "retain", "position" => "retain", "recovery" => "fresh_cycle"},
    "merged.visual_segment_done_early" => {"visual" => "fresh_cycle", "movement" => "freeze", "position" => "freeze", "recovery" => "freeze"},
    "merged.movement_accept" => {"visual" => "retain", "movement" => "freeze", "position" => "freeze", "recovery" => "freeze"},
    "merged.movement_done_early" => {"visual" => "retain", "movement" => "fresh_cycle", "position" => "retain", "recovery" => "fresh_cycle"},
    "merged.movement_already_moved" => {"visual" => "retain", "movement" => "fresh_cycle", "position" => "retain", "recovery" => "fresh_cycle"},
    "merged.movement_position_changed" => {"visual" => "retain", "movement" => "retain", "position" => "rotate_position_cycle_preserving_enablement", "recovery" => "retain"},
    "merged.movement_skip" => {"visual" => "retain", "movement" => "fresh_cycle", "position" => "retain", "recovery" => "deferral_increment"},
    "merged.visual_only" => {"visual" => "retain", "movement" => "retain", "position" => "retain", "recovery" => "deferral_increment"},
    "merged.escape_during_visual" => {"visual" => "fresh_cycle", "movement" => "fresh_cycle", "position" => "retain", "recovery" => "deferral_increment"},
  }
  expected_segment_by_phase = {
    "visual_offered" => "none", "visual_running" => "visual", "movement_offered" => "none", "movement_running" => "movement",
    "position_offered" => "none", "recovery_offered" => "none", "recovery_running" => "recovery",
    "merged_visual_running" => "visual", "merged_movement_offered" => "movement", "merged_movement_running" => "movement",
  }
  live_phases.all? do |phase, row|
    row.fetch("control_remote_actions").all? do |control_id, remote_id|
      target = remote_registry[remote_id]
      guard = guards[target]
      transition = transition_by_id[target]
      resolver_names = resolver_groups.select { |_, ids| ids.include?(target) }.keys
      next false unless target && target == expected_registry[remote_id] && guard && transition && resolver_names.length == 1
      phase_ok = guard.fetch("source_phases").include?(phase) && guard.fetch("target_phase") == expected_target_phase.fetch(target)
      kind_ok = guard.fetch("opportunity_kinds") == [row.fetch("opportunity_kind")] ||
        (target == "companion.take_with_me" && guard.fetch("opportunity_kinds").include?(row.fetch("opportunity_kind")))
      participant_ok = guard.fetch("participant_guard") == row.fetch("participant_guard") ||
        (target == "companion.take_with_me" && guard.fetch("participant_guard") == "exact_registered_participant_set")
      affected = guard.fetch("affected_nonparticipants", [])
      expected_affected = control_id == "change_position" && row.fetch("opportunity_kind") != "position" ? %w[position] : []
      affected_ok = affected == expected_affected && (affected - row.fetch("allowed_affected_nonparticipants")).empty?
      fact_ok = transition.fetch("facts") == expected_facts.fetch(target)
      ledger_ok = transition.fetch("ledgers") == (target == "companion.take_with_me" ? %w[companion_action operational] : %w[product_fact])
      expected_resolver = if control_id == "take_with_me" || control_id.start_with?("start_")
        "authoritative_opportunity_nonterminal"
      elsif phase == "merged_visual_running"
        "merged_visual_cross_slot_candidate_set"
      else
        "terminal_candidate_set"
      end
      resolver_slot_ok = resolver_names.first == expected_resolver
      expected_slot = if target == "companion.take_with_me" || target == "merged.movement_accept"
        "none_nonterminal"
      elsif target == "merged.visual_segment_done_early"
        "visual_segment"
      else
        "opportunity_close"
      end
      actual_slot = if transition.fetch("terminal") == false && resolver_names.first == "authoritative_opportunity_nonterminal"
        "none_nonterminal"
      elsif target == "merged.visual_segment_done_early" && resolver_names.first == "merged_visual_cross_slot_candidate_set"
        "visual_segment"
      else
        "opportunity_close"
      end
      segment_ok = row.fetch("segment") == expected_segment_by_phase.fetch(phase) &&
        if phase == "merged_visual_running"
          guard.fetch("required_payload").include?("visual_segment_id") || target == "companion.take_with_me"
        elsif %w[merged_movement_offered merged_movement_running].include?(phase)
          guard.fetch("required_payload").include?("movement_segment_id") || target == "companion.take_with_me"
        else
          true
        end
      phase_ok && kind_ok && participant_ok && affected_ok && fact_ok && ledger_ok &&
        resolver_slot_ok && expected_slot == actual_slot && segment_ok &&
        transition.fetch("clocks") == expected_clocks.fetch(target)
    end
  end
end
assert(valid_remote_semantics?(live_phases, remote_registry, expected_remote_registry, guards, transition_by_id, resolver_groups), "every companion wrapper must match exact source/target phase, kind, participants, segment, slot, fact, ledgers, resolver, and effects")
wrong_phase_remote = Marshal.load(Marshal.dump(remote_registry))
wrong_phase_remote["companion.visual.skip"] = "movement.skip_running"
assert(!valid_remote_semantics?(live_phases, wrong_phase_remote, expected_remote_registry, guards, transition_by_id, resolver_groups), "wrong-phase companion wrapper mutation must fail")
start_target_phase_mutation = Marshal.load(Marshal.dump(guards))
start_target_phase_mutation["merged.movement_accept"]["target_phase"] = "terminal_provisional"
assert(!valid_remote_semantics?(live_phases, remote_registry, expected_remote_registry, start_target_phase_mutation, transition_by_id, resolver_groups), "remote Start target-phase mutation must fail")
deleted_take_phase = Marshal.load(Marshal.dump(live_phases))
deleted_take_phase["visual_running"]["control_ids"].delete("take_with_me")
deleted_take_phase["visual_running"]["focus_order"].delete("take_with_me")
deleted_take_phase["visual_running"]["control_remote_actions"].delete("take_with_me")
deleted_take_phase["visual_running"]["focus_target"] = "done_early"
assert(!valid_live_phase_registry?(deleted_take_phase, expected_live_phases, expected_live_phase_controls, control_catalog, action_groups, remote_registry), "deleting Take with me from visual running must fail phase parity")
timer_projection = runtime.fetch("timer_recovery_user_projection")
recovery_menu = timer_projection.dig("exact_copy", "menu_status_by_projected_evidence")
pause_reasons = timer_projection.dig("exact_copy", "paused_reason_registry")
expected_pause_reasons = %w[manual_pause outside_working_hours system_inactive system_locked system_sleeping system_unavailable confirmed_away accepted_ritual intentionally_hidden_system_reason]
expected_reason_projection_requires = %w[evidence_kind_registered_in_paused_reason_registry exact_evidence_record_id evidence_record_revision coordinator_generation evidence_currentness_and_reason_specific_freshness_at_recovery_disposition retained_preterminal_evidence_snapshot_digest display_value_exactly_from_the_winning_registry_row]
expected_reason_precedence = {
  "manual_pause" => 0,
  "system_locked" => 10,
  "system_inactive" => 11,
  "system_sleeping" => 20,
  "system_unavailable" => 21,
  "accepted_ritual" => 30,
  "confirmed_away" => 40,
  "outside_working_hours" => 50,
  "intentionally_hidden_system_reason" => 60,
}
overlapping_reasons = timer_projection.dig("exact_copy", "overlapping_system_trace")
assert(
  timer_projection.dig("exact_copy", "title") == "Timer couldn’t be restored" &&
    timer_projection.dig("exact_copy", "due", "body") == "No finish was recorded. This schedule is still due." &&
    timer_projection.dig("exact_copy", "not_due_or_manual_early", "body").include?("schedule was not reset") &&
    recovery_menu.fetch("active_due") == "Still due · timer not restored" &&
    recovery_menu.fetch("paused_due_template") == recovery_menu.fetch("paused_not_due_template") &&
    recovery_menu.fetch("held_due_template") == recovery_menu.fetch("held_not_due_template") &&
    recovery_menu.fetch("paused_due_template").include?("qualified_pause_reason") &&
    recovery_menu.fetch("paused_hidden_system_reason") == "Paused · timer not restored" &&
    recovery_menu.fetch("held_due_template").include?("qualified_hold_reason") &&
    pause_reasons.keys == expected_pause_reasons &&
    pause_reasons.fetch("manual_pause").fetch("selected_reason_required") == true &&
    expected_pause_reasons.drop(1).all? { |reason| pause_reasons.fetch(reason).fetch("selected_reason_required") == false } &&
    pause_reasons.fetch("intentionally_hidden_system_reason").fetch("display").include?("paused_hidden_system_reason") &&
    timer_projection.dig("exact_copy", "reason_projection_requires") == expected_reason_projection_requires &&
    timer_projection.dig("exact_copy", "reason_precedence_smallest_wins") == expected_reason_precedence &&
    overlapping_reasons.fetch("evidence_input_order_a") == %w[system_unavailable system_sleeping system_locked] &&
    overlapping_reasons.fetch("evidence_input_order_b") == %w[system_locked system_unavailable system_sleeping] &&
    overlapping_reasons.fetch("bound_winner") == "system_locked" &&
    overlapping_reasons.fetch("display") == "Mac locked" &&
    overlapping_reasons.fetch("rule").include?("same_record_revision_snapshot_and_copy") &&
    timer_projection.fetch("phase_selection_rule").include?("menu status independently") &&
    timer_projection.dig("interaction", "initial_focus") == "close_action" &&
    timer_projection.dig("interaction", "quiet_transition").include?("60_second_grace"),
  "timer recovery user projection must condition due copy on the retained schedule phase",
)
recovery_precedence_mutation = timer_projection.dig("exact_copy", "reason_precedence_smallest_wins").merge("system_unavailable" => 9)
assert(recovery_precedence_mutation != expected_reason_precedence, "timer recovery reason precedence mutation must fail")
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
  nonterminal.key?("conflict_key_reduction"),
  "nonterminal reconciliation must compose one winner per conflict key",
)
assert(
  nonterminal.fetch("rule").downcase.include?("arrival order is never an input") &&
    nonterminal.dig("conflict_key_reduction", "same_key_winner_sort") == %w[causally_satisfied_exact_scope_revision smallest_transition_rank_within_conflict_key lexicographically_smallest_action_id] &&
    nonterminal.dig("conflict_key_reduction", "apply_rule").include?("every_compatible_disjoint_key"),
  "nonterminal reconciliation must be deterministic and arrival-independent",
)
coordinator = runtime.dig("action_contract", "authoritative_action_coordinator")
scope_contract = coordinator["scope_contract"]
assert(
  scope_contract &&
    scope_contract.dig("opportunity", "identity_fields") == %w[opportunity_id opportunity_revision] &&
    scope_contract.dig("global", "identity_fields") == %w[global_state_id global_state_revision] &&
    scope_contract.dig("global", "forbidden_identity_fields") == ["opportunity_id"] &&
    scope_contract.dig("global", "optional_atomic_opportunity_context_fields") == %w[expected_opportunity_id expected_opportunity_revision expected_opportunity_projection_epoch_id expected_running_phase_and_segment_id] &&
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
authoritative_rank = nonterminal.fetch("transition_rank_within_conflict_key_smallest_wins")
conflict_keys = nonterminal.dig("conflict_key_reduction", "registered_conflict_key_by_transition")
authoritative_ids = authoritative_opportunity_ids + authoritative_global_ids
assert(
  authoritative_rank.keys.sort == authoritative_ids.sort &&
    authoritative_rank.values.uniq.length == authoritative_rank.values.length &&
    conflict_keys.keys.sort == authoritative_ids.sort &&
    nonterminal.fetch("order_coverage_rule").include?("exactly the union"),
  "authoritative nonterminal rank and conflict-key registry must be total and match resolver membership",
)
matching_evidence_pairs = [
  %w[pause.start pause.resume],
  %w[hold.begin hold.release],
  %w[hold.begin hold.correction_release],
  %w[system.unavailable system.available],
  %w[system.unavailable system.available_after_extended_unavailable],
  %w[system.long_idle_began system.returned_from_long_idle],
  %w[sensor.strong_movement_restart schedule_restart.undo],
]
assert(
  matching_evidence_pairs.all? do |begin_id, clear_id|
    begin_key = conflict_keys.fetch(begin_id)
    clear_key = conflict_keys.fetch(clear_id)
    begin_key.is_a?(Hash) &&
      begin_key == clear_key &&
      begin_key.keys.sort == %w[identity_fields kind] &&
      !begin_key.fetch("identity_fields").any? { |field| %w[operation rank transition_id action_id].include?(field) }
  end,
  "matching evidence begin/clear actions must share identical conflict-key kind and identity bytes",
)
assert(
  coordinator.fetch("lease_maximum_seconds") == 90 &&
    coordinator.fetch("rule").include?("before any product fact, deadline, phase, or clock effect") &&
    coordinator.fetch("rule").include?("offline") &&
    coordinator.fetch("rule").include?("Later cannot orphan"),
  "effect-bearing nonterminal actions require one bounded authoritative coordinator",
)
atomic_running = coordinator.fetch("atomic_global_running_commit")
assert(
  %w[pause.start pause.resume hold.begin hold.release hold.correction_release working_hours.exit working_hours.enter system.unavailable system.available].all? { |id| atomic_running.fetch("applies_to").include?(id) } &&
    atomic_running.fetch("order").include?("advance_and_fence_the_old_opportunity_revision") &&
    atomic_running.fetch("order").include?("create_the_successor_opportunity_revision_for_the_same_opportunity_and_projection_epoch") &&
    atomic_running.fetch("order").include?("rebase_the_exact_phase_segment_accepted_deadline_remaining_duration_and_retained_snapshot_onto_the_successor_revision") &&
    atomic_running.fetch("rebase_rule").include?("never preserves the old opportunity revision") &&
    atomic_running.fetch("rebase_rule").include?("without replay, reset, or wall-time extension") &&
    atomic_running.fetch("order").include?("reject_every_uncommitted_candidate_for_the_old_revision_with_a_current_state_receipt") &&
    atomic_running.fetch("order").include?("acknowledge_global_and_opportunity_successor_revisions_together") &&
    atomic_running.fetch("reverse_arrival_rule").include?("Watch terminal action") &&
    atomic_running.fetch("reverse_arrival_rule").include?("cannot finish, skip, or reset") &&
    atomic_running.fetch("already_committed_rule").include?("no rollback"),
  "global evidence commands must atomically compare and fence a running opportunity",
)
replay = runtime.dig("action_contract", "action_id_replay_contract")
replay_receipts = replay.fetch("user_receipts")
ack_of_ack = replay.fetch("acknowledgement_of_ack_envelope")
outcome_ack = replay.fetch("outcome_ack_envelope")
outcome_ack_pending = replay.fetch("outcome_ack_pending")
def ack_uuid_bytes(value)
  [value.delete("-")].pack("H*")
end
def ack_u32_string(value)
  [value.bytesize].pack("N") + value
end
def ack_fixed_hex(value, expected_bytes)
  bytes = [value].pack("H*")
  raise "wrong fixed-byte vector width" unless bytes.bytesize == expected_bytes
  bytes
end
def encode_outcome_ack_vector(contract)
  values = contract.fetch("executable_known_vector").fetch("values")
  bytes = ack_u32_string(contract.fetch("domain_literal"))
  bytes << [contract.fetch("schema_version")].pack("n")
  bytes << ack_uuid_bytes(values.fetch("global_state_id"))
  bytes << [values.fetch("coordinator_generation")].pack("Q>")
  bytes << ack_uuid_bytes(values.fetch("coordinator_monotonic_epoch_id"))
  bytes << [values.fetch("outcome_created_ticks"), values.fetch("coordinator_key_epoch")].pack("Q>Q>")
  bytes << ack_fixed_hex(values.fetch("coordinator_key_id_hex"), 32)
  bytes << ack_uuid_bytes(values.fetch("intended_receiver_device_id"))
  bytes << ack_fixed_hex(values.fetch("intended_receiver_key_id_hex"), 32)
  bytes << [values.fetch("intended_receiver_key_epoch")].pack("Q>")
  bytes << ack_fixed_hex(values.fetch("action_id_digest_hex"), 32)
  bytes << [values.fetch("origin_device_counter")].pack("Q>")
  bytes << [contract.dig("enum_vocabularies", "outcome_code_enum_uint16", values.fetch("outcome_code"))].pack("n")
  bytes << [values.fetch("global_state_revision")].pack("Q>")
  bytes << [1].pack("C") << [values.fetch("opportunity_revision")].pack("Q>")
  bytes << ack_fixed_hex(values.fetch("delivery_token_hex"), 32)
  bytes << [values.fetch("coordinator_expiry_ticks")].pack("Q>")
  bytes
end
def encode_ack_of_ack_vector(contract)
  values = contract.fetch("executable_known_vector").fetch("values")
  bytes = ack_u32_string(contract.fetch("domain_literal"))
  bytes << [contract.fetch("schema_version")].pack("n")
  bytes << ack_uuid_bytes(values.fetch("global_state_id"))
  bytes << [values.fetch("coordinator_generation"), values.fetch("acknowledging_device_key_epoch")].pack("Q>Q>")
  bytes << ack_fixed_hex(values.fetch("acknowledging_device_key_id_hex"), 32)
  bytes << ack_uuid_bytes(values.fetch("acknowledging_device_id"))
  bytes << ack_fixed_hex(values.fetch("action_id_digest_hex"), 32)
  bytes << [values.fetch("origin_device_counter"), values.fetch("global_state_revision")].pack("Q>Q>")
  bytes << [1].pack("C") << [values.fetch("opportunity_revision")].pack("Q>")
  bytes << ack_fixed_hex(values.fetch("delivery_token_hex"), 32)
  bytes << [values.fetch("coordinator_expiry_ticks")].pack("Q>")
  bytes << ack_fixed_hex(values.fetch("outcome_replay_binding_digest_hex"), 32)
  bytes
end
expected_ack_fields = [
  {"name" => "domain_literal", "type" => "utf8_nfc_string_u32_length"},
  {"name" => "schema_version", "type" => "unsigned_uint16_big_endian"},
  {"name" => "global_state_id", "type" => "uuid_16_network_bytes"},
  {"name" => "coordinator_generation", "type" => "unsigned_uint64_big_endian"},
  {"name" => "acknowledging_device_key_epoch", "type" => "unsigned_uint64_big_endian"},
  {"name" => "acknowledging_device_key_id", "type" => "fixed_32_raw_bytes"},
  {"name" => "acknowledging_device_id", "type" => "uuid_16_network_bytes"},
  {"name" => "action_id_digest", "type" => "fixed_32_raw_bytes"},
  {"name" => "origin_device_counter", "type" => "unsigned_uint64_big_endian"},
  {"name" => "outcome_revision", "type" => "outcome_revision_v1"},
  {"name" => "delivery_token", "type" => "fixed_32_raw_bytes"},
  {"name" => "coordinator_expiry_ticks", "type" => "unsigned_uint64_big_endian"},
  {"name" => "outcome_replay_binding_digest", "type" => "fixed_32_raw_bytes"},
]
expected_outcome_ack_fields = [
  {"name" => "domain_literal", "type" => "utf8_nfc_string_u32_length"},
  {"name" => "schema_version", "type" => "unsigned_uint16_big_endian"},
  {"name" => "global_state_id", "type" => "uuid_16_network_bytes"},
  {"name" => "coordinator_generation", "type" => "unsigned_uint64_big_endian"},
  {"name" => "coordinator_monotonic_epoch_id", "type" => "uuid_16_network_bytes"},
  {"name" => "outcome_created_ticks", "type" => "unsigned_uint64_big_endian"},
  {"name" => "coordinator_key_epoch", "type" => "unsigned_uint64_big_endian"},
  {"name" => "coordinator_key_id", "type" => "fixed_32_raw_bytes"},
  {"name" => "intended_receiver_device_id", "type" => "uuid_16_network_bytes"},
  {"name" => "intended_receiver_key_id", "type" => "fixed_32_raw_bytes"},
  {"name" => "intended_receiver_key_epoch", "type" => "unsigned_uint64_big_endian"},
  {"name" => "action_id_digest", "type" => "fixed_32_raw_bytes"},
  {"name" => "origin_device_counter", "type" => "unsigned_uint64_big_endian"},
  {"name" => "outcome_code", "type" => "outcome_code_enum_uint16"},
  {"name" => "outcome_revision", "type" => "outcome_revision_v1"},
  {"name" => "delivery_token", "type" => "fixed_32_raw_bytes"},
  {"name" => "coordinator_expiry_ticks", "type" => "unsigned_uint64_big_endian"},
]
def valid_ack_of_ack?(ack, expected_fields)
  ack.fetch("domain_literal") == "cadence.timing-runtime-v2.ack-of-ack.v1" &&
    ack.fetch("schema_version") == 1 &&
    ack.fetch("canonical_bytes_version") == "ack_of_ack_bytes_v1" &&
    ack.fetch("ordered_typed_fields") == expected_fields &&
    ack.dig("exact_nested_types", "outcome_revision_v1", "ordered_fields") == [
      {"name" => "global_state_revision", "type" => "unsigned_uint64_big_endian"},
      {"name" => "opportunity_revision", "type" => "optional_unsigned_uint64_v1"},
    ] &&
    ack.dig("exact_nested_types", "optional_unsigned_uint64_v1", "present_bytes") == "unsigned_uint8_1_then_unsigned_uint64_big_endian" &&
    ack.dig("signature", "algorithm") == "ed25519" &&
    ack.dig("signature", "verification_key").include?("device_id_key_id_and_key_epoch") &&
    ack.fetch("delivery_token_rule").include?("exactly_32_raw_bytes") &&
    ack.fetch("replay_binding_rule") == "sha256_of_the_exact_complete_signed_outcome_ack_bytes_v1_including_its_64_signature_bytes" &&
    ack.fetch("verification_order").last.include?("erases_its_compact_receipt") &&
    ack.fetch("sender_outbox_erasure_rule").include?("outcome_ack_pending") &&
    ack.fetch("sender_outbox_erasure_rule").include?("independent")
end
def valid_outcome_ack?(ack, expected_fields)
  ack.fetch("domain_literal") == "cadence.timing-runtime-v2.outcome-ack.v1" &&
    ack.fetch("schema_version") == 1 &&
    ack.fetch("canonical_bytes_version") == "outcome_ack_bytes_v1" &&
    ack.fetch("ordered_typed_fields") == expected_fields &&
    ack.dig("exact_nested_types", "outcome_revision_v1", "ordered_fields") == [
      {"name" => "global_state_revision", "type" => "unsigned_uint64_big_endian"},
      {"name" => "opportunity_revision", "type" => "optional_unsigned_uint64_v1"},
    ] &&
    ack.dig("enum_vocabularies", "outcome_code_enum_uint16") == {
      "committed" => 1,
      "rejected_no_op" => 2,
      "already_ended" => 3,
      "expired_too_old_to_verify" => 4,
      "transfer_failed" => 5,
    } &&
    ack.dig("signature", "algorithm") == "ed25519" &&
    ack.dig("signature", "verification_key").include?("selected_by_key_id_and_epoch") &&
    ack.fetch("executable_encoding").include?("no map, set, reordered field, unknown tag, or trailing byte") &&
    ack.fetch("replay_binding") == "sha256_of_the_exact_complete_signed_outcome_ack_bytes_v1_including_its_64_signature_bytes" &&
    ack.fetch("verification_order").include?("persist_local_receive_epoch_and_ticks_then_require_local_same_epoch_elapsed_less_than_90_seconds_for_ack_of_ack_relaunch")
end
assert(
  replay.fetch("maximum_receipt_seconds") == 90 &&
    replay.fetch("retention_rule").include?("delivery_acknowledgement_of_ack") &&
    replay.fetch("delivery_protocol").last.include?("never_erases_the_receipt") &&
    replay.fetch("exact_duplicate_while_receipt_present").include?("replay_original_outcome") &&
    replay.fetch("exact_duplicate_while_receipt_present").include?("without_reapplying") &&
    replay.fetch("duplicate_or_unseen_after_receipt_expiry").include?("too_old_to_verify") &&
    replay_receipts.fetch("exact_duplicate") == "Action already received. Showing the recorded result." &&
    replay_receipts.fetch("uncertainty_safe") == "That action is too old to verify. Showing the current timer." &&
    replay.fetch("lost_ack_trace").include?("effect_fact_notification_and_haptic_counts_remain_one") &&
    replay.fetch("lost_ack_trace").last.include?("acknowledges_receipt_of_the_outcome") &&
    replay.fetch("prohibited_copy") == "no_change_was_recorded" &&
    valid_ack_of_ack?(ack_of_ack, expected_ack_fields) &&
    valid_outcome_ack?(outcome_ack, expected_outcome_ack_fields) &&
    outcome_ack_pending.fetch("maximum_retention_seconds") == 90 &&
    outcome_ack_pending.fetch("atomic_persisted_fields").include?("exact_complete_signed_outcome_ack_bytes_v1") &&
    outcome_ack_pending.fetch("atomic_persisted_fields").include?("outcome_revision") &&
    outcome_ack_pending.fetch("atomic_persisted_fields").include?("coordinator_expiry_ticks") &&
    outcome_ack_pending.fetch("atomic_persisted_fields").include?("intended_receiver_device_id_key_id_and_key_epoch") &&
    protocol_outcome_pending.fetch("fields").include?("receiver_device_id_and_key_id_and_epoch") &&
    outcome_ack_pending.fetch("relaunch_rule").include?("same_local_monotonic_epoch") &&
    outcome_ack_pending.fetch("epoch_mismatch_rule").include?("erase_without_transmission_without_recreating_the_action") &&
    outcome_ack_pending.fetch("no_recursive_ack_rule").include?("does not wait for an acknowledgement of its acknowledgement-of-ack"),
  "ActionID retry receipt must survive until acknowledgement-of-ack or expiry and remain uncertainty-safe",
)
outcome_ack_vector = outcome_ack.fetch("executable_known_vector")
outcome_ack_vector_bytes = encode_outcome_ack_vector(outcome_ack)
ack_of_ack_vector = ack_of_ack.fetch("executable_known_vector")
ack_of_ack_vector_bytes = encode_ack_of_ack_vector(ack_of_ack)
assert(
  outcome_ack_vector_bytes.unpack1("H*") == outcome_ack_vector.fetch("unsigned_canonical_bytes_hex") &&
    Digest::SHA256.hexdigest(outcome_ack_vector_bytes) == outcome_ack_vector.fetch("unsigned_sha256_hex") &&
    outcome_ack_vector.fetch("signature_placement") == "append_exactly_64_raw_ed25519_signature_bytes_to_the_unsigned_canonical_bytes" &&
    ack_of_ack_vector_bytes.unpack1("H*") == ack_of_ack_vector.fetch("unsigned_canonical_bytes_hex") &&
    Digest::SHA256.hexdigest(ack_of_ack_vector_bytes) == ack_of_ack_vector.fetch("unsigned_sha256_hex") &&
    ack_of_ack_vector.fetch("signature_placement") == "append_exactly_64_raw_ed25519_signature_bytes_to_the_unsigned_canonical_bytes",
  "outcome ACK and acknowledgement-of-ack executable byte vectors drifted",
)
ack_width_mutation = Marshal.load(Marshal.dump(ack_of_ack))
ack_width_mutation["ordered_typed_fields"][6]["type"] = "unsigned_uint32_big_endian"
assert(!valid_ack_of_ack?(ack_width_mutation, expected_ack_fields), "ack-of-ack width mutation must fail")
outcome_name_mutation = Marshal.load(Marshal.dump(outcome_ack))
outcome_name_mutation["ordered_typed_fields"][13]["name"] = "result_code"
outcome_tag_mutation = Marshal.load(Marshal.dump(outcome_ack))
outcome_tag_mutation["enum_vocabularies"]["outcome_code_enum_uint16"]["committed"] = 9
outcome_order_mutation = Marshal.load(Marshal.dump(outcome_ack))
outcome_order_mutation["ordered_typed_fields"][4], outcome_order_mutation["ordered_typed_fields"][5] = outcome_order_mutation["ordered_typed_fields"][5], outcome_order_mutation["ordered_typed_fields"][4]
assert(
  !valid_outcome_ack?(outcome_name_mutation, expected_outcome_ack_fields) &&
    !valid_outcome_ack?(outcome_tag_mutation, expected_outcome_ack_fields) &&
    !valid_outcome_ack?(outcome_order_mutation, expected_outcome_ack_fields),
  "outcome ACK name/tag/order mutations must fail",
)
counter_contract = runtime.dig("action_contract", "device_counter_contract")
sender_outbox = counter_contract.fetch("sender_crash_replay_outbox")
assert(
  counter_contract.fetch("generated_sequence").include?("strict_contiguous_gap_free") &&
    counter_contract.fetch("persisted_high_water_meaning").include?("contiguous_coordinator_disposition_not_a_received_claim") &&
    counter_contract.fetch("advance_rule").include?("Never leap over a hole") &&
    counter_contract.dig("sparse_pending_window", "maximum_retention_seconds") == 90 &&
    counter_contract.dig("sparse_pending_window", "class") == "class_0_ephemeral" &&
    counter_contract.dig("counter_11_before_10_trace", "first_result").include?("high_water_remains_9") &&
    counter_contract.dig("counter_11_before_10_trace", "second_result").include?("high_water_becomes_11") &&
    counter_contract.dig("gap_expiry_trace", "later_counter_10_receipt") == "That action is too old to verify. Showing the current timer." &&
    counter_contract.fetch("device_allocation_order").first.include?("atomically_persist") &&
    sender_outbox.fetch("maximum_retention_seconds") == 90 &&
    sender_outbox.fetch("atomic_fields").include?("canonical_action_envelope_required_to_resend_exactly_once") &&
    sender_outbox.fetch("relaunch_rule").include?("exact same ActionID, counter, receiver, key epoch, and envelope") &&
    sender_outbox.fetch("relaunch_rule").include?("elapsed is strictly less than 90") &&
    sender_outbox.fetch("epoch_mismatch_or_missing_anchor_rule").include?("erase_raw_outbox_without_resend_do_not_create_replacement") &&
    counter_contract.fetch("sender_crash_traces").keys == %w[crash_before_atomic_reservation crash_after_atomic_reservation_before_send crash_after_send_before_outcome crash_after_outcome_before_ack_of_ack reboot_changes_monotonic_epoch expiry_or_unrecoverable_corruption] &&
    counter_contract.dig("sender_crash_traces", "reboot_changes_monotonic_epoch").include?("without_resend_or_replacement"),
  "per-device counters must survive sender crashes and remain contiguous across out-of-order delivery",
)
exact_300 = nonterminal.dig("conflict_key_reduction", "exact_300_collision_trace")
dual_clear = nonterminal.dig("conflict_key_reduction", "release_composition_trace")
same_record = nonterminal.dig("conflict_key_reduction", "same_record_competition_trace")
opportunity_frontier = nonterminal.fetch("opportunity_action_frontier")
assert(
  exact_300.fetch("committed_winners") == %w[system.unavailable system.long_idle_began] &&
    exact_300.fetch("result").include?("both_evidence_records_are_set") &&
    dual_clear.fetch("committed_winners") == %w[pause.resume system.available] &&
    dual_clear.fetch("result").include?("both_named_records_clear") &&
    same_record.fetch("candidate_count_for_key") == 2 &&
    same_record.fetch("winner_by_registered_same_key_rank") == "pause.start",
  "conflict-key reduction must compose disjoint set and clear evidence at the exact 300-second edge",
)
frontier_traces = opportunity_frontier.fetch("arrival_order_traces")
expected_frontier_ranks = {
  "explicit_skip_or_escape_terminal" => 0,
  "other_terminal" => 10,
  "take_with_me_handoff" => 20,
  "merged_start_5" => 30,
  "merged_start_2" => 31,
  "other_effect_bearing_nonterminal" => 40,
}
assert(
  opportunity_frontier.fetch("covers") == %w[merged_movement_offered_start_5_vs_start_2_vs_explicit_skip_or_escape running_take_with_me_vs_any_terminal_control every_other_effect_bearing_nonterminal_vs_terminal_candidate_for_the_same_opportunity_revision] &&
    opportunity_frontier.fetch("settlement").include?("No product fact, accepted deadline, authority transfer, haptic, or running projection") &&
    opportunity_frontier.fetch("winner_sort").last == "lexicographically_smallest_action_id" &&
    opportunity_frontier.fetch("registered_opportunity_intent_rank") == expected_frontier_ranks &&
    frontier_traces.dig("start_then_skip", "winner") == frontier_traces.dig("skip_then_start", "winner") &&
    frontier_traces.dig("start_then_skip", "fact_history") == frontier_traces.dig("skip_then_start", "fact_history") &&
    frontier_traces.dig("start_then_escape", "winner") == frontier_traces.dig("escape_then_start", "winner") &&
    frontier_traces.dig("start_then_escape", "fact_history") == frontier_traces.dig("escape_then_start", "fact_history") &&
    frontier_traces.dig("start_2_then_skip", "winner") == frontier_traces.dig("skip_then_start_2", "winner") &&
    frontier_traces.dig("start_2_then_skip", "winner") == "companion.merged.movement_skip" &&
    frontier_traces.dig("start_5_then_start_2", "winner") == frontier_traces.dig("start_2_then_start_5", "winner") &&
    frontier_traces.dig("start_5_then_start_2", "winner") == "companion.merged.movement_start_5" &&
    frontier_traces.dig("start_5_then_start_2", "resulting_phase") == "merged_movement_running" &&
    frontier_traces.dig("handoff_then_done", "winner") == frontier_traces.dig("done_then_handoff", "winner") &&
    frontier_traces.dig("handoff_then_done", "fact_history") == frontier_traces.dig("done_then_handoff", "fact_history") &&
    opportunity_frontier.fetch("commit_order").include?("commit_at_most_one_product_fact_and_one_clock_effect_set_for_that_frontier"),
  "cross-resolver opportunity-action frontier must settle Start/Skip/Escape and handoff/terminal races arrival-independently",
)
frontier_winner_mutation = Marshal.load(Marshal.dump(frontier_traces))
frontier_winner_mutation["skip_then_start"]["winner"] = "companion.merged.movement_start_5"
assert(frontier_winner_mutation.dig("start_then_skip", "winner") != frontier_winner_mutation.dig("skip_then_start", "winner"), "arrival-order winner mutation must fail")
frontier_rank_mutation = opportunity_frontier.fetch("registered_opportunity_intent_rank").merge("take_with_me_handoff" => 5)
assert(frontier_rank_mutation != expected_frontier_ranks, "frontier rank mutation must fail")
restart_safety = nonterminal.fetch("schedule_restart_safety")
undo_binding = restart_safety.fetch("undo_binding")
assert(
  restart_safety.fetch("applies_to") == %w[sensor.strong_movement_restart schedule_restart.undo] &&
    restart_safety.fetch("guard").include?("paused_or_held_suspended_overlay") &&
    restart_safety.fetch("blocked_disposition").include?("Do not rotate, restore, or mutate") &&
    undo_binding.fetch("availability").include?("Ordinary eligible accrual") &&
    undo_binding.fetch("availability").include?("terminal fact, ritual acceptance, schedule restart, or cycle rotation") &&
    undo_binding.fetch("delta_restore_rule").include?("predecision accumulated") &&
    undo_binding.fetch("delta_restore_rule").include?("eligible deltas") &&
    undo_binding.fetch("stale_user_receipt") == "That restart can no longer be undone. Your current schedule was not changed." &&
    undo_binding.fetch("stale_voiceover_announcement").include?("Your current schedule was not changed. Close.") &&
    undo_binding.fetch("accrue_then_undo_trace").last.include?("successor_correction_revisions") &&
    undo_binding.fetch("stale_disposition").include?("keep_every_later_fact_and_clock_effect") &&
    undo_binding.fetch("restart_finish_undo_trace").last == "no_partial_snapshot_restore_occurs" &&
    %w[expected_unchanged_post_decision_structural_revision_vector expected_predecision_snapshot_digest expected_terminal_fact_ritual_restart_and_rotation_frontiers post_restart_eligible_accrual_delta_by_clock].all? { |field| guards.fetch("schedule_restart.undo").fetch("required_payload").include?(field) } &&
    %w[sensor.strong_movement_restart schedule_restart.undo].all? do |id|
      guards.fetch(id).fetch("required_payload").include?("no_unresolved_running_ritual_including_suspended_paused_or_held_overlay")
    end,
  "schedule restart and undo must not mutate cycles under a running or suspended ritual snapshot",
)
evidence_reduction = runtime.dig("presentation_states", "evidence_reduction")
assert(
  evidence_reduction.fetch("rule").include?("mutates only its named evidence record") &&
    evidence_reduction.dig("running_projection", "rule").include?("fences the predecessor opportunity revision") &&
    evidence_reduction.dig("running_projection", "rule").include?("creates a successor") &&
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
%w[pause.start working_hours.exit system.unavailable].each do |id|
  assert(guards.fetch(id).fetch("source_phases") == ["any_nonclosed"], "#{id} must remain reachable while a ritual runs")
  assert(guards.fetch(id).fetch("required_payload").include?("optional_suspended_running_state"), "#{id} must preserve suspended running state")
end
%w[hold.begin hold.release hold.correction_release].each do |id|
  assert(guards.fetch(id).fetch("phase_scope") == "global_with_optional_opportunity", "#{id} must be global evidence, not opportunity identity")
  assert(guards.fetch(id).fetch("source_phases") == ["any_state_including_accumulating_without_opportunity"], "#{id} must be reachable before due without an OpportunityID")
  assert(guards.fetch(id).fetch("opportunity_kinds").include?("none"), "#{id} must not require an opportunity")
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
    fence.fetch("persisted_coordinator_state_requires").include?("contiguous_action_disposition_high_water_by_paired_device") &&
    fence.fetch("persisted_coordinator_state_requires").include?("last_committed_fence_digest_bytes") &&
    fence.fetch("persisted_coordinator_state_requires").include?("installation_local_signing_ed25519_key_id_key_epoch_and_public_key_exactly_32_raw_bytes") &&
    fence.fetch("signed_fence_requires").include?("coordinator_key_id_and_key_epoch") &&
    fence.fetch("signed_fence_requires").include?("ed25519_signature_from_installation_local_coordinator_key") &&
    fence.fetch("every_opportunity_closure_order").last == "then_allow_successor_cycle_or_opportunity_eligibility" &&
    fence.fetch("coordinator_epoch_loss_order").include?("reject_every_later_arriving_old_generation_action_as_operational_no_op") &&
    fence.fetch("old_generation_receipt") == "action_too_old_to_verify_show_current_projected_state" &&
    fence.fetch("bounded_rule").include?("never waits for an old monotonic expiry"),
  "closure and epoch-loss fences must be persisted, signed, high-water, and bounded",
)
signed_fence = fence.fetch("signed_fence_portable_encoding")
expected_fence_fields = [
  {"name" => "domain_literal", "type" => "string_u32_length_nfc_utf8"},
  {"name" => "schema_version", "type" => "unsigned_uint16_big_endian"},
  {"name" => "global_state_id", "type" => "uuid_16_network_bytes"},
  {"name" => "global_state_revision", "type" => "unsigned_uint64_big_endian"},
  {"name" => "closing_coordinator_generation", "type" => "unsigned_uint64_big_endian"},
  {"name" => "successor_coordinator_generation", "type" => "unsigned_uint64_big_endian"},
  {"name" => "coordinator_key_epoch", "type" => "unsigned_uint64_big_endian"},
  {"name" => "coordinator_key_id", "type" => "fixed_32_raw_bytes"},
  {"name" => "opportunity_context", "type" => "optional_opportunity_context_v1"},
  {"name" => "contiguous_action_disposition_high_water_by_device", "type" => "counted_map_uuid_to_unsigned_uint64"},
  {"name" => "selected_outcome", "type" => "selected_outcome_union_v1"},
  {"name" => "fence_reason", "type" => "fence_reason_enum_uint16"},
  {"name" => "previous_fence_digest", "type" => "optional_fixed_32_bytes"},
]
def valid_signed_fence_contract?(contract, expected_fields)
  nested = contract.fetch("exact_nested_types", {})
  enums = contract.fetch("enum_vocabularies", {})
  scalars = contract.fetch("scalar_encoding", {})
  collections = contract.fetch("collection_encoding", {})
  contract.fetch("domain_literal", nil) == "cadence.timing-runtime-v2.projection-fence.v1" &&
    contract.fetch("schema_version", nil) == 1 &&
    contract.fetch("canonical_bytes_version", nil) == "projection_fence_bytes_v1" &&
    contract.fetch("self_contained_rule", "").include?("must not inherit") &&
    scalars == {
      "unsigned_uint8" => "one_raw_byte",
      "unsigned_uint16" => "two_bytes_big_endian",
      "unsigned_uint32" => "four_bytes_big_endian",
      "unsigned_uint64" => "eight_bytes_big_endian",
      "uuid" => "exactly_16_rfc4122_network_order_bytes_after_lowercase_hyphenated_text_normalization",
      "string" => "unicode_nfc_utf8_prefixed_by_unsigned_uint32_big_endian_byte_length",
      "fixed_32_bytes" => "exactly_32_raw_bytes_without_length_prefix",
      "optional" => "one_unsigned_uint8_tag_0_absent_or_1_present_then_present_payload",
      "enum" => "unsigned_uint16_big_endian_registered_numeric_tag",
      "tagged_union" => "one_unsigned_uint8_registered_variant_tag_then_exact_variant_payload",
    } &&
    collections.fetch("map", "").include?("unsigned_uint32_big_endian_entry_count") &&
    collections.fetch("set", "").include?("unsigned_uint32_big_endian_element_count") &&
    collections.fetch("array", "").include?("unsigned_uint32_big_endian_element_count") &&
    contract.fetch("ordered_typed_fields", nil) == expected_fields &&
    nested.dig("optional_opportunity_context_v1", "presence_tag") == "unsigned_uint8_0_absent_1_present" &&
    nested.dig("optional_opportunity_context_v1", "present_fields_in_order") == [
      {"name" => "opportunity_id", "type" => "uuid_16_network_bytes"},
      {"name" => "projection_epoch_id", "type" => "uuid_16_network_bytes"},
      {"name" => "predecessor_opportunity_revision", "type" => "unsigned_uint64_big_endian"},
      {"name" => "successor_opportunity_revision", "type" => "unsigned_uint64_big_endian"},
    ] &&
    nested.dig("optional_opportunity_context_v1", "direction_rule").include?("must_not_equal_or_precede_the_predecessor") &&
    nested.dig("optional_opportunity_context_v1", "selected_outcome_binding") == "selected_outcome_projection_revision_must_equal_successor_opportunity_revision" &&
    nested.dig("counted_map_uuid_to_unsigned_uint64", "cardinality") == "unsigned_uint32_big_endian_entry_count" &&
    nested.dig("selected_outcome_union_v1", "tag_width") == "unsigned_uint8" &&
    nested.dig("selected_outcome_union_v1", "variants", 1, "payload") == "unsigned_uint64_big_endian" &&
    nested.dig("selected_outcome_union_v1", "variants", 2, "payload") == "operational_disposition_enum_uint16" &&
    nested.dig("optional_fixed_32_bytes", "present_payload") == "exactly_32_unencoded_bytes_without_a_length_prefix" &&
    enums.fetch("fence_reason_enum_uint16", {}).values == [1, 2, 3, 4, 5] &&
    enums.fetch("operational_disposition_enum_uint16", {}).values == [1, 2, 3, 4, 5] &&
    contract.fetch("digest", "").include?("32_raw_bytes") &&
    contract.fetch("signature_domain_literal", "") == "cadence.timing-runtime-v2.projection-fence-signature.v1" &&
    contract.fetch("signing_input", "").include?("string_u32_length_nfc_utf8_then_exact_32_digest_bytes") &&
    contract.fetch("signature", "").start_with?("ed25519") &&
    contract.fetch("public_key_rule", "").include?("exact 32 raw") &&
    contract.fetch("public_key_rule", "").include?("signed coordinator_key_id and coordinator_key_epoch") &&
    contract.fetch("public_key_rule", "").include?("fingerprint is derived display metadata only") &&
    contract.fetch("verification_order", []).include?("reject_unknown_domain_schema_version_type_width_enum_value_union_tag_or_collection_cardinality") &&
    contract.fetch("storage_rule", "").include?("exactly_32_unencoded_bytes")
end
assert(valid_signed_fence_contract?(signed_fence, expected_fence_fields), "signed fence canonical bytes are incomplete or nonportable")
def uuid_bytes(value)
  [value.delete("-")].pack("H*")
end
def u32_string(value)
  [value.bytesize].pack("N") + value
end
def encode_fence_known_vector(values, map_pairs, previous_digest)
  bytes = u32_string("cadence.timing-runtime-v2.projection-fence.v1")
  bytes << [1].pack("n")
  bytes << uuid_bytes(values.fetch("global_state_id"))
  bytes << [values.fetch("global_state_revision"), values.fetch("closing_coordinator_generation"), values.fetch("successor_coordinator_generation"), values.fetch("coordinator_key_epoch")].pack("Q>Q>Q>Q>")
  bytes << [values.fetch("coordinator_key_id_hex")].pack("H*")
  bytes << [1].pack("C")
  bytes << uuid_bytes(values.fetch("opportunity_id"))
  bytes << uuid_bytes(values.fetch("projection_epoch_id"))
  bytes << [values.fetch("predecessor_opportunity_revision"), values.fetch("successor_opportunity_revision")].pack("Q>Q>")
  sorted_pairs = map_pairs.sort_by { |device_id, _| uuid_bytes(device_id).bytes }
  bytes << [sorted_pairs.length].pack("N")
  sorted_pairs.each { |device_id, high_water| bytes << uuid_bytes(device_id) << [high_water].pack("Q>") }
  bytes << [1].pack("C") << [values.fetch("selected_projection_revision")].pack("Q>")
  bytes << [3].pack("n")
  bytes << [1].pack("C") << previous_digest
  bytes
end
fence_vector = signed_fence.fetch("executable_known_vector")
fence_values = fence_vector.fetch("values")
reverse_map_pairs = [["00000000-0000-0000-0000-000000000002", 5], ["00000000-0000-0000-0000-000000000001", 4]]
fence_vector_bytes = encode_fence_known_vector(fence_values, reverse_map_pairs, [fence_vector.fetch("previous_fence_digest_hex")].pack("H*"))
assert(
  fence_vector_bytes.unpack1("H*") == fence_vector.fetch("canonical_bytes_hex") &&
    Digest::SHA256.hexdigest(fence_vector_bytes) == fence_vector.fetch("sha256_hex") &&
    encode_fence_known_vector(fence_values, reverse_map_pairs.reverse, [fence_vector.fetch("previous_fence_digest_hex")].pack("H*")) == fence_vector_bytes,
  "projection fence executable bytes/digest/map ordering vector drifted",
)
domain_mutation = Marshal.load(Marshal.dump(signed_fence))
domain_mutation["domain_literal"] = "cadence.timing-runtime-v2.projection-fence.v2"
version_mutation = Marshal.load(Marshal.dump(signed_fence))
version_mutation["schema_version"] = 2
order_mutation = Marshal.load(Marshal.dump(signed_fence))
order_mutation["ordered_typed_fields"][2], order_mutation["ordered_typed_fields"][3] = order_mutation["ordered_typed_fields"][3], order_mutation["ordered_typed_fields"][2]
width_mutation = Marshal.load(Marshal.dump(signed_fence))
width_mutation["exact_nested_types"]["selected_outcome_union_v1"]["tag_width"] = "unsigned_uint16"
scalar_width_mutation = Marshal.load(Marshal.dump(signed_fence))
scalar_width_mutation["scalar_encoding"]["unsigned_uint32"] = "eight_bytes_big_endian"
tag_mutation = Marshal.load(Marshal.dump(signed_fence))
tag_mutation["exact_nested_types"]["selected_outcome_union_v1"]["variants"][1]["payload"] = "unsigned_uint32_big_endian"
cardinality_mutation = Marshal.load(Marshal.dump(signed_fence))
cardinality_mutation["exact_nested_types"]["counted_map_uuid_to_unsigned_uint64"]["cardinality"] = "none"
revision_swap_mutation = Marshal.load(Marshal.dump(signed_fence))
revision_swap_mutation["exact_nested_types"]["optional_opportunity_context_v1"]["present_fields_in_order"][2], revision_swap_mutation["exact_nested_types"]["optional_opportunity_context_v1"]["present_fields_in_order"][3] = revision_swap_mutation["exact_nested_types"]["optional_opportunity_context_v1"]["present_fields_in_order"][3], revision_swap_mutation["exact_nested_types"]["optional_opportunity_context_v1"]["present_fields_in_order"][2]
revision_binding_mutation = Marshal.load(Marshal.dump(signed_fence))
revision_binding_mutation["exact_nested_types"]["optional_opportunity_context_v1"]["selected_outcome_binding"] = "projection_revision_may_differ"
assert(
  !valid_signed_fence_contract?(domain_mutation, expected_fence_fields) &&
    !valid_signed_fence_contract?(version_mutation, expected_fence_fields) &&
    !valid_signed_fence_contract?(order_mutation, expected_fence_fields) &&
    !valid_signed_fence_contract?(width_mutation, expected_fence_fields) &&
    !valid_signed_fence_contract?(scalar_width_mutation, expected_fence_fields) &&
    !valid_signed_fence_contract?(tag_mutation, expected_fence_fields) &&
    !valid_signed_fence_contract?(cardinality_mutation, expected_fence_fields) &&
    !valid_signed_fence_contract?(revision_swap_mutation, expected_fence_fields) &&
    !valid_signed_fence_contract?(revision_binding_mutation, expected_fence_fields),
  "signed fence domain/version/field-order/width/tag/cardinality/revision-direction mutations must fail",
)
assert(
  terminal.fetch("originated_after_known_closure") == "operational_expired_before_acceptance_show_current_projected_state" &&
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
byte_authority = runtime.dig("identities", "executable_byte_encoding_authority")
segment_identity = runtime.dig("identities", "merged_segment_id")
assert(
  encoding.fetch("version") == "cadence_contract_bytes_v1" &&
    encoding.fetch("hash_algorithm") == "sha256" &&
    encoding.dig("scalar_encoding", "uuid").include?("16_network_order_bytes") &&
    encoding.dig("scalar_encoding", "string").include?("unicode_nfc_utf8") &&
    encoding.dig("scalar_encoding", "byte_string").include?("unmodified_bytes") &&
    encoding.dig("scalar_encoding", "tagged_union").include?("registered_variant_tag") &&
    encoding.dig("scalar_encoding", "struct").include?("exact_registered_schema_order") &&
    encoding.dig("collection_encoding", "list").include?("uint32_big_endian_count") &&
    encoding.dig("collection_encoding", "set").include?("uint32_big_endian_cardinality") &&
    encoding.dig("collection_encoding", "set").include?("sorted_unsigned_lexicographically") &&
    encoding.dig("collection_encoding", "map").include?("uint32_big_endian_entry_count") &&
    encoding.fetch("prohibited_inputs") == %w[wall_time localized_copy process_hash_seed pointer_address] &&
    identifier_contract.fetch("wire_text") == "lowercase_hyphenated_rfc4122" &&
    identifier_contract.fetch("deterministic_identifier_rule").include?("explicit domain literal") &&
    byte_authority.fetch("implementation_contract") == "timing_runtime_exact_bytes_v1" &&
    byte_authority.fetch("registered_schemas") == %w[merged_segment_id_bytes_v1 projection_fence_bytes_v1 outcome_ack_bytes_v1 ack_of_ack_bytes_v1] &&
    byte_authority.fetch("rule").include?("sole byte authority") &&
    byte_authority.fetch("collection_rule").include?("unsigned cardinality width"),
  "portable identifier encoding is incomplete or platform-dependent",
)
def merged_segment_uuid(opportunity_id, kind_tag)
  bytes = u32_string("cadence.timing-runtime-v2.merged-segment-id.v1")
  bytes << uuid_bytes(opportunity_id) << [kind_tag].pack("C") << [1].pack("Q>")
  digest = Digest::SHA256.digest(bytes).bytes.first(16)
  digest[6] = (digest[6] & 0x0f) | 0x80
  digest[8] = (digest[8] & 0x3f) | 0x80
  hex = digest.pack("C*").unpack1("H*")
  [hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12]].join("-")
end
segment_fixture = segment_identity.fetch("known_vector_fixture")
assert(
  segment_identity.fetch("canonical_bytes_version") == "merged_segment_id_bytes_v1" &&
    segment_identity.dig("enum_vocabularies", "segment_kind_enum_uint8") == {"visual" => 1, "movement" => 2} &&
    merged_segment_uuid(segment_fixture.fetch("opportunity_id"), 1) == segment_fixture.fetch("visual_expected_uuid") &&
    merged_segment_uuid(segment_fixture.fetch("opportunity_id"), 2) == segment_fixture.fetch("movement_expected_uuid") &&
    guards.fetch("merged.accept").fetch("creates_before_target_projection") == ["visual_segment_id"] &&
    %w[merged.visual_segment_finished merged.visual_segment_done_early].all? { |id| guards.fetch(id).fetch("creates_before_target_projection") == ["movement_segment_id"] } &&
    guards.fetch("companion.take_with_me").fetch("required_payload").include?("current_segment_id_when_segmented") &&
    guards.select { |_, guard| guard.fetch("source_phases", []).include?("merged_visual_running") && guard.fetch("target_phase") != "unchanged" }.all? { |_, guard| guard.fetch("required_payload").include?("visual_segment_id") } &&
    guards.select { |_, guard| (guard.fetch("source_phases", []) & %w[merged_movement_offered merged_movement_running]).any? }.all? { |_, guard| (guard.fetch("required_payload") & %w[movement_segment_id current_segment_id_when_segmented]).any? || guard.fetch("source_phases").include?("any_nonclosed") },
  "merged segment IDs must use executable deterministic vectors and be created before every guard use",
)
segment_kind_mutation = Marshal.load(Marshal.dump(segment_identity))
segment_kind_mutation["enum_vocabularies"]["segment_kind_enum_uint8"]["visual"] = 2
assert(segment_kind_mutation.dig("enum_vocabularies", "segment_kind_enum_uint8") != {"visual" => 1, "movement" => 2}, "segment kind-tag mutation must fail")
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
assert(
  [product_model, interaction, health, flows, copy].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("positive finite v1") &&
      (normalized.include?("5-second") || normalized.include?("visual 5 s"))
  end &&
    [product_model, interaction, health, flows, copy].all? { |document| document.include?("new") && document.include?("edit") },
  "legacy Custom storage compatibility and safer new-authoring bounds are not reconciled",
)
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
    decisions.include?("D-043 contract-repair addendum") &&
    conformance.include?("conditional unknown-timer projection"),
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
  "Sending “%@”…",
  "Reconnecting…",
  "Connection lost. Checking whether “%@” was received; do not repeat.",
  "That action no longer applies. Showing the current timer.",
  "Ended on another device.",
  "Couldn’t transfer. The timer is still running on this Mac.",
  "Retry · Check status · Close · Cancel transfer · Cancel reconnect",
].each do |phrase|
  assert(copy.include?(phrase), "companion copy missing #{phrase}")
end
assert(
  expected_companion_states.all? { |state| accessibility.include?(state.tr("_", "-")) } &&
  flows.include?("duplicate with compact receipt") &&
    flows.include?("too old to verify") &&
    screens.include?("Cancel transfer") && screens.include?("Cancel reconnect") &&
    screens.include?("selected action") &&
    accessibility.include?("Do not repeat") &&
    copy.include?("CP-VO39") &&
    copy.include?("That action is too old to verify. Showing the current timer. Close.") &&
    accessibility.include?("CP-VO39 exactly once") && screens.include?("CP-VO39 exactly once") &&
    health.include?("companion.visual.skip") &&
    interaction.include?("matching generation") && interaction.include?("projection epoch") &&
    interaction.include?("opportunity revision") && interaction.include?("segment") &&
    !copy.include?("No change was recorded"),
  "companion UX/a11y flow is not reconciled across governing documents",
)
[
  "Timer couldn’t be restored",
  "No finish was recorded. This schedule is still due.",
  "Still due · timer not restored",
  "No finish was recorded. The timer was not restored, and this schedule was not reset.",
  "%@ · timer not restored",
  "Paused: %@ · timer not restored",
  "Held: %@ · timer not restored",
].each do |phrase|
  assert(
    copy.gsub(/\s+/, " ").include?(phrase),
    "timer recovery copy missing #{phrase}",
  )
end
assert(
  [screens, interaction, accessibility, health].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("schedule was not reset") && normalized.include?("still due") &&
      normalized.include?("Paused") && normalized.include?("Held")
  end,
  "conditional due/not-due timer recovery copy is not reconciled across governing documents",
)
assert(
  privacy.gsub(/\s+/, " ").include?("**90 seconds**") &&
    privacy.gsub(/\s+/, " ").include?("no durable record identity") &&
    privacy.gsub(/\s+/, " ").include?("never enter an") &&
    privacy.gsub(/\s+/, " ").include?("Delete history") &&
    privacy.gsub(/\s+/, " ").include?("Reset app data") &&
    copy.include?("Temporary action buffers") &&
    privacy.gsub(/\s+/, " ").include?("compact Class-0 replay receipt") &&
    conformance.include?("payload-free compact ActionID replay receipt"),
  "candidate privacy lifecycle is incomplete across privacy/copy/conformance",
)
assert(
  [product_model, interaction, health, decisions].all? { |document| document.include?("conflict-key") } &&
    interaction.include?("Pause resume plus") && interaction.include?("lock") && interaction.include?("exactly 300 seconds") &&
    health.include?("all compatible disjoint-record winners") &&
    product_model.include?("Hold may begin before due") &&
    interaction.include?("reverse-arriving Watch terminal") &&
    [product_model, interaction, health, decisions].all? { |document| document.gsub(/\s+/, " ").include?("identity bytes") } &&
    [product_model, interaction, health].all? { |document| document.include?("Paused/Held-suspended") || document.include?("Paused/Held suspended") },
  "conflict-key evidence composition, pre-due Held, and atomic running fence are not canonical across prose",
)
assert(
  [interaction, health, decisions].all? { |document| document.include?("cadence.timing-runtime-v2.projection-fence.v1") || document.include?("registered domain/version") } &&
    interaction.include?("mutated domain, version, type, width, tag, cardinality, order, digest, or signature fails closed"),
  "portable signed-fence contract is missing from canonical prose",
)
assert(
  [product_model, interaction, health, flows, privacy].all? { |document| document.include?("compact") } &&
    replay_receipts.values.all? { |receipt| copy.include?(receipt) } &&
    [product_model, interaction, health, flows, privacy].all? { |document| document.include?("acknowledgement-of-ack") } &&
    [product_model, interaction, health, flows, privacy].all? { |document| document.include?("too old to verify") } &&
    !copy.include?("No change was recorded"),
  "ActionID lost-ack replay and truthful stale receipts are not reconciled",
)
assert(
  product_model.include?("visual time accrued before that movement cannot cause a prompt") &&
    health.include?("Visual time accrued before that likely-away interval cannot cause a") &&
    product_model.include?("A genuinely new") &&
    health.include?("new fresh or Custom visual cycle"),
  "trust guarantee must apply to pre-movement/pre-away accrual without banning new cycles",
)
assert(
  [product_model, interaction, health, authority, conformance].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("predecessor") && normalized.include?("successor") && normalized.include?("rebase")
  end &&
    [product_model, interaction, health].none? { |document| document.match?(/revision (?:stay|stays|remain|remains|is) suspended/i) },
  "global/running prose must fence the predecessor and rebase onto a successor revision",
)
assert(
  [product_model, interaction, health, flows, screens, accessibility].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("Start 5") && normalized.include?("Start 2") &&
      normalized.match?(/Escape(?: and|\/| or) Command-period.*dismiss/i)
  end &&
    [product_model, interaction, health, flows, screens, accessibility].all? { |document| document.include?("explicit Skip") || document.include?("Skip") },
  "companion merged offer and projection-only Escape are not reconciled",
)
assert(
  [product_model, interaction, health, flows, privacy, authority, conformance].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("crash-replay") && normalized.include?("90") && normalized.include?("acknowledgement-of-ack")
  end && copy.include?("crash_outbox_detail"),
  "sender crash outbox lifecycle is not reconciled across canonical documents",
)
assert(
  [interaction, health, decisions].all? { |document| document.include?("projection_fence_bytes_v1") } &&
    [interaction, health, decisions].all? { |document| document.include?("actual 32-byte") } &&
    [interaction, health, privacy].all? { |document| document.include?("cadence.timing-runtime-v2.ack-of-ack.v1") },
  "independent fence bytes, actual verification keys, and signed ack-of-ack are not canonical",
)
assert(
  [product_model, health].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("revision vector") && normalized.include?("snapshot") && normalized.include?("stale") && normalized.include?("later fact")
  end,
  "restart Undo staleness is not reconciled",
)
assert(
  [interaction, health, flows, screens, accessibility, copy].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("Paused · timer not restored") &&
      (normalized.include?("selected reason") || normalized.include?("selected Pause reason"))
  end,
  "timer recovery manual/system Pause reason projections are incomplete",
)
assert(
  [product_model, interaction, health, flows, privacy, authority, conformance].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("same") && normalized.include?("monotonic epoch") &&
      normalized.include?("90") && normalized.include?("outcome_ack_pending")
  end &&
    [product_model, interaction, health, flows, privacy, authority].all? do |document|
      normalized = document.gsub(/\s+/, " ")
      normalized.include?("without resend") || normalized.include?("without transmission") ||
        normalized.include?("erase without resend")
    end,
  "same-epoch sender-outbox and minimized outcome-ACK crash continuation are not canonical",
)
assert(
  [product_model, interaction, health, flows, authority, conformance].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("segment") && normalized.include?("visual") && normalized.include?("movement") &&
      normalized.include?("opportunity-action frontier")
  end,
  "deterministic merged segment creation and the cross-resolver frontier are not reconciled",
)
assert(
  [product_model, interaction, health, flows, screens, accessibility, copy, authority, conformance].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("nonterminal") && normalized.include?("Start")
  end &&
    %w[nonterminal-action-pending offline-nonterminal-ack-unknown revalidating-nonterminal-ack-unknown].all? do |state|
      screens.downcase.include?(state) && accessibility.downcase.include?(state)
    end &&
    copy.include?("Starting “%@”…") && copy.include?("Checking whether “%@” started; do not repeat."),
  "remote Start pending/unknown/revalidation copy and accessibility registry are incomplete",
)
assert(
  [product_model, interaction, health, flows, authority, conformance, privacy].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("selected receiver") && normalized.include?("key") && normalized.include?("epoch")
  end && copy.include?("Send to: %@") && accessibility.include?("Send to [paired name]") &&
    screens.include?("Send to [paired name]"),
  "handoff receiver and key-epoch binding are not reconciled across security and UI contracts",
)
assert(
  [product_model, interaction, health, flows, authority, decisions].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("eligible") && normalized.include?("delta") && normalized.include?("Undo") &&
      normalized.include?("stale")
  end && copy.include?("That restart can no longer be undone. Your current schedule was not changed.") &&
    accessibility.include?("Restart Undo — stale receipt") && screens.include?("Restart Undo stale receipt"),
  "delta-preserving Undo and its stale receipt are not reconciled",
)
assert(
  [product_model, interaction, health, flows, authority, copy, accessibility, screens].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("dirty") && normalized.include?("untouched")
  end,
  "Custom partial-edit dirty-field/group preservation is not reconciled",
)
assert(
  [interaction, health, authority, decisions].all? do |document|
    normalized = document.gsub(/\s+/, " ").downcase
    normalized.include?("one executable") && normalized.include?("predecessor") &&
      normalized.include?("successor") && normalized.include?("outcome_ack_bytes_v1")
  end,
  "one executable byte authority and directional global fence are not canonical",
)
assert(
  [interaction, health, screens, accessibility, copy, authority, conformance].all? do |document|
    normalized = document.gsub(/\s+/, " ")
    normalized.include?("locked") && normalized.include?("sleep") &&
      normalized.include?("unavailable") && normalized.include?("timer not restored")
  end &&
    [interaction, health, screens, accessibility].all? do |document|
      document.gsub(/\s+/, " ").include?("precedence")
    end &&
    [interaction, health, decisions].all? { |document| document.include?("evidence") },
  "timer-recovery evidence binding and deterministic overlapping-reason projection are incomplete",
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
