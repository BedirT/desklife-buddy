#!/usr/bin/ruby
# frozen_string_literal: true

# Story #19: locks the canonical machine key paths cited by design prose.
# Fails when a cited path is missing or an honesty invariant stops holding,
# so prose↔machine drift surfaces here instead of as pixel mismatches.

require "date"
require "yaml"

abort "usage: check_canonical_keys.rb <research.yaml> <runtime.yaml>" unless ARGV.length == 2

input_path, runtime_path = ARGV
document = YAML.safe_load(File.read(input_path), permitted_classes: [Date])
runtime_document = YAML.safe_load(File.read(runtime_path), permitted_classes: [Date])

failures = []

lookup = lambda do |root, dotted|
  dotted.split(".").reduce(root) do |node, key|
    break nil unless node.is_a?(Hash) && node.key?(key)

    node[key]
  end
end

check_present = lambda do |root, file, dotted|
  failures << "missing #{file}:#{dotted}" if lookup.call(root, dotted).nil?
end

check_false = lambda do |root, file, dotted|
  value = lookup.call(root, dotted)
  failures << "#{file}:#{dotted} must be false, got #{value.inspect}" unless value == false
end

profiles = %w[gentle balanced frequent_movement research_informed_high_frequency]
profiles.each do |profile|
  %w[visual movement].each do |clock|
    %w[soft_due_seconds target_seconds latest_preferred_seconds].each do |key|
      check_present.call(document, "product_protocol.yaml", "profiles.#{profile}.#{clock}.#{key}")
    end
  end
  check_present.call(document, "product_protocol.yaml", "profiles.#{profile}.visual.duration_seconds")
  check_present.call(document, "product_protocol.yaml", "profiles.#{profile}.movement.recommended_duration_seconds")
  check_present.call(document, "product_protocol.yaml", "profiles.#{profile}.movement.quick_duration_seconds")
end

%w[
  eligible_after_seconds latest_typical_seconds
  suggested_duration_min_seconds suggested_duration_max_seconds
  required_movement_deferrals maximum_offers_per_session
].each do |key|
  check_present.call(document, "product_protocol.yaml", "profiles.balanced.recovery.#{key}")
end

%w[recent_input_window_seconds long_idle_reset_seconds wake_unlock_grace_seconds].each do |key|
  check_present.call(document, "product_protocol.yaml", "activity_estimator.#{key}")
end

%w[
  wait_for_low_friction_moment merge_window_seconds heads_up_default
  heads_up_seconds_before_target snooze_options_seconds
  max_repeated_escalations_per_opportunity lockout_allowed
].each do |key|
  check_present.call(document, "product_protocol.yaml", "opportunity_delivery.#{key}")
end

%w[visual movement position_change likely_natural_interruption].each do |key|
  check_present.call(document, "product_protocol.yaml", "completion_semantics.#{key}")
end
check_present.call(document, "product_protocol.yaml", "permissions.required_for_core")

expected_precedence = %w[
  manual_pause system_inactive_or_locked explicit_presentation_mode focus_filter
  calendar_busy excluded_application outside_working_hours snooze low_friction_wait
]
actual_precedence = lookup.call(document, "suppression_precedence")
if actual_precedence != expected_precedence
  failures << "product_protocol.yaml:suppression_precedence must be #{expected_precedence.inspect}, got #{actual_precedence.inspect}"
end

check_false.call(document, "product_protocol.yaml", "opportunity_delivery.lockout_allowed")
check_false.call(document, "product_protocol.yaml", "completion_semantics.position_change.resets_movement_clock")
check_false.call(document, "product_protocol.yaml", "completion_semantics.likely_natural_interruption.counts_as_movement")
check_false.call(document, "product_protocol.yaml", "completion_semantics.movement.inferred_from_idle")

check_present.call(runtime_document, "timing_runtime_v2.yaml", "visual_delivery.latest_after_target_seconds")
%w[
  low_friction_input_pause_seconds post_interruption_grace_seconds
  maximum_sample_gap_seconds long_idle_visual_action long_idle_movement_action
  movement_timer_visual_action
].each do |key|
  check_present.call(runtime_document, "timing_runtime_v2.yaml", "activity_estimator.#{key}")
end

# Values cited as exact numbers in INTERACTION_SPEC.md section 2. Research
# latest_preferred_seconds values are asserted as-is: the visual scheduling
# override lives in timing_runtime_v2 latest_after_target_seconds (also locked).
expected_values = {
  "profiles.gentle.visual.soft_due_seconds" => 1500,
  "profiles.gentle.visual.target_seconds" => 1800,
  "profiles.gentle.visual.latest_preferred_seconds" => 2100,
  "profiles.gentle.visual.duration_seconds" => 20,
  "profiles.gentle.movement.soft_due_seconds" => 4200,
  "profiles.gentle.movement.target_seconds" => 4500,
  "profiles.gentle.movement.latest_preferred_seconds" => 5400,
  "profiles.gentle.movement.recommended_duration_seconds" => 300,
  "profiles.gentle.movement.quick_duration_seconds" => 120,
  "profiles.balanced.visual.soft_due_seconds" => 1200,
  "profiles.balanced.visual.target_seconds" => 1500,
  "profiles.balanced.visual.latest_preferred_seconds" => 1800,
  "profiles.balanced.visual.duration_seconds" => 20,
  "profiles.balanced.movement.soft_due_seconds" => 3000,
  "profiles.balanced.movement.target_seconds" => 3600,
  "profiles.balanced.movement.latest_preferred_seconds" => 4200,
  "profiles.balanced.movement.recommended_duration_seconds" => 300,
  "profiles.balanced.movement.quick_duration_seconds" => 120,
  "profiles.balanced.recovery.eligible_after_seconds" => 5400,
  "profiles.balanced.recovery.latest_typical_seconds" => 7200,
  "profiles.balanced.recovery.suggested_duration_min_seconds" => 300,
  "profiles.balanced.recovery.suggested_duration_max_seconds" => 600,
  "profiles.balanced.recovery.required_movement_deferrals" => 2,
  "profiles.balanced.recovery.maximum_offers_per_session" => 1,
  "profiles.frequent_movement.visual.soft_due_seconds" => 1200,
  "profiles.frequent_movement.visual.target_seconds" => 1500,
  "profiles.frequent_movement.visual.latest_preferred_seconds" => 1800,
  "profiles.frequent_movement.visual.duration_seconds" => 20,
  "profiles.frequent_movement.movement.soft_due_seconds" => 1800,
  "profiles.frequent_movement.movement.target_seconds" => 2100,
  "profiles.frequent_movement.movement.latest_preferred_seconds" => 2400,
  "profiles.frequent_movement.movement.recommended_duration_seconds" => 300,
  "profiles.frequent_movement.movement.quick_duration_seconds" => 120,
  "profiles.research_informed_high_frequency.visual.soft_due_seconds" => 1200,
  "profiles.research_informed_high_frequency.visual.target_seconds" => 1200,
  "profiles.research_informed_high_frequency.visual.latest_preferred_seconds" => 1500,
  "profiles.research_informed_high_frequency.visual.duration_seconds" => 20,
  "profiles.research_informed_high_frequency.movement.soft_due_seconds" => 1500,
  "profiles.research_informed_high_frequency.movement.target_seconds" => 1800,
  "profiles.research_informed_high_frequency.movement.latest_preferred_seconds" => 2100,
  "profiles.research_informed_high_frequency.movement.recommended_duration_seconds" => 300,
  "profiles.research_informed_high_frequency.movement.quick_duration_seconds" => 120,
  "activity_estimator.recent_input_window_seconds" => 60,
  "activity_estimator.long_idle_reset_seconds" => 300,
  "activity_estimator.wake_unlock_grace_seconds" => 90,
  "opportunity_delivery.wait_for_low_friction_moment" => true,
  "opportunity_delivery.merge_window_seconds" => 300,
  "opportunity_delivery.heads_up_default" => true,
  "opportunity_delivery.heads_up_seconds_before_target" => 45,
  "opportunity_delivery.snooze_options_seconds" => [300, 600, 900],
  "opportunity_delivery.max_repeated_escalations_per_opportunity" => 1,
}
expected_values.each do |dotted, expected|
  actual = lookup.call(document, dotted)
  failures << "product_protocol.yaml:#{dotted} must be #{expected.inspect}, got #{actual.inspect}" unless actual == expected
end

# Only Balanced carries recovery. Anywhere else it would fork the schedule contract.
%w[gentle frequent_movement research_informed_high_frequency].each do |profile|
  value = lookup.call(document, "profiles.#{profile}.recovery")
  failures << "product_protocol.yaml:profiles.#{profile} must not carry recovery, got #{value.inspect}" unless value.nil?
end

runtime_values = {
  "visual_delivery.latest_after_target_seconds" => 90,
  "activity_estimator.low_friction_input_pause_seconds" => 5,
  "activity_estimator.post_interruption_grace_seconds" => 60,
  "activity_estimator.maximum_sample_gap_seconds" => 90,
  "activity_estimator.long_idle_visual_action" => "restart_without_completion",
  "activity_estimator.long_idle_movement_action" => "preserve_without_completion",
  "activity_estimator.movement_timer_visual_action" => "restart_without_completion",
}
runtime_values.each do |dotted, expected|
  actual = lookup.call(runtime_document, dotted)
  failures << "timing_runtime_v2.yaml:#{dotted} must be #{expected.inspect}, got #{actual.inspect}" unless actual == expected
end

if failures.empty?
  puts "canonical keys: #{profiles.length} profiles, precedence, and honesty invariants hold"
else
  warn "canonical key violations:"
  failures.each { |failure| warn "  #{failure}" }
  exit 1
end
