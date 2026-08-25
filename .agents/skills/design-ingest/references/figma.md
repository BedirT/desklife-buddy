# Figma sources

Prefer an owner-provided export or authenticated read-only inspection. Freeze:

- file, page, frame, component, and variant identifiers;
- source version or inspected timestamp plus exported-content digest;
- desktop frame dimensions and scale;
- component properties, constraints, layout rules, variables, styles, and
  interaction links;
- every reachable state, light/dark appearance, empty/loading/error case, and
  overlay/window state;
- exported assets with format, bounds, and rights.

Do not infer token equality from similar pixels. Map Figma variables and styles
to existing DesignSystem tokens by semantic intent. A missing token is a
separate design-system decision. For canonical mode, list every non-identical
substitution. For native-adaptation, explain each platform substitution. For
directional mode, list the small set of retained design-DNA rules and anti-goals.

If authenticated inspection is unavailable, freeze the supplied frame exports
and explicitly lower confidence. Do not claim hidden states or component logic.
