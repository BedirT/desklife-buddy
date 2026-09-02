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
expected_new_presets = %w[calm balanced_v2 frequent_reset adaptive custom]
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
  protocol.dig("preset_contract_v2", "legacy_identifier_disposition").keys
    .reject { |key| key == "rule" }.sort == expected_legacy_profiles.sort,
  "legacy profile disposition is incomplete",
)
assert(
  protocol.dig("preset_contract_v2", "new_install_default") == "balanced_v2",
  "new-install default must be balanced_v2",
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
  protocol.dig("preset_contract_v2", "legacy_identifier_disposition", "research_informed_high_frequency", "suggested_successor") == "custom" &&
    protocol.dig("preset_contract_v2", "legacy_identifier_disposition", "research_informed_high_frequency", "successor_seed") == "exact_v1_snapshot",
  "legacy high-frequency migration must seed exact values into custom",
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
assert(
  runtime.dig("input_and_motion", "declaration_guard_seconds") == 0,
  "D-032 requires no declaration-key delay",
)
assert(
  runtime.dig("terminal_reconciliation", "rules").include?(
    "arrival_order_never_selects_the_winner",
  ),
  "terminal reconciliation must be order-independent",
)
%w[clock_cycle_id opportunity_id action_id decision_id device_id session_id].each do |identity|
  assert(runtime.fetch("identities").key?(identity), "missing #{identity} contract")
end
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
