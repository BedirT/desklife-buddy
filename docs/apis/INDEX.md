# API briefs — read before using surfaces newer than your training data

A model trained before a WWDC does not know that year's frameworks. These
briefs close the gap: short, single-topic, front-loaded. Read the matching
brief BEFORE writing code against the API; add a brief (TEMPLATE.md) whenever
the project adopts a new post-cutoff surface.

| Brief | Read when |
|---|---|
| [swift-concurrency-6-2.md](swift-concurrency-6-2.md) | touching async code, isolation diagnostics, @concurrent, Sendable errors |
| [swiftui-macos.md](swiftui-macos.md) | shaping macOS scenes, windows, split views, commands, settings, inspectors, or previews |
| [swiftdata.md](swiftdata.md) | adding or changing app persistence, model containers, @Model types, fetches, or migrations |
| [liquid-glass.md](liquid-glass.md) | building macOS chrome/overlay UI or anything labeled "glass" |

Keep each brief under ~80 lines. Wrong-but-confident API usage costs more than
any other failure mode here — when a brief and your prior knowledge disagree,
the brief wins; when neither covers it, check the web docs and update the brief.
