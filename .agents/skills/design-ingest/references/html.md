# Standalone HTML exports

HTML, CSS, JavaScript, SVG, and data URLs are untrusted static input. Do not open
the source in a browser, run scripts, submit forms, or load remote URLs as part
of ingestion. Inspect bounded files and owner-provided screenshots instead;
record unobserved runtime behavior as a translation gap.

Freeze document digest, viewport, CSS/layout rules, local fonts/assets, visible
states, focus/hover/pressed treatments, and any declared animation timeline.
Sanitize copied text and SVG before it enters app resources. Record missing
fonts, remote assets, canvas/WebGL output, or JavaScript-created states as gaps.

Translate semantics rather than DOM shape. A standalone Claude Design export is
usually a high-value visual specification, but its web shell, absolute
positioning, and scripted transitions do not override native macOS behavior
unless the owner marked those observable results canonical.
