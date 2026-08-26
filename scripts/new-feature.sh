#!/bin/bash -p
# Scaffold a macOS feature module and add it to the stable AppFeatures product.
# App.xcodeproj links that umbrella once, so feature creation never edits pbxproj.
#
# Usage: scripts/new-feature.sh <Name>     e.g. scripts/new-feature.sh Settings
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NAME="${1:?feature name in UpperCamelCase, e.g. Settings}"
if [[ ! "$NAME" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
  echo "Name must be UpperCamelCase alphanumeric: $NAME" >&2
  exit 2
fi
case "$NAME" in
  App|AppFeatures|AppTests|Domain|DesignSystem|FeatureLocalization|Features|Foundation|Observation|PackageDescription|SnapshotSupport|SwiftUI|TestSupport|Testing)
    echo "Feature name is reserved by the harness or generated imports: $NAME" >&2
    exit 2
    ;;
esac

SRC_DIR="$ROOT/Packages/Features/Sources/$NAME"
TEST_DIR="$ROOT/Packages/Features/Tests/${NAME}Tests"
if [[ -e "$SRC_DIR" || -e "$TEST_DIR" ]]; then
  echo "Feature $NAME already exists under Packages/Features" >&2
  exit 2
fi

LOWER_NAME="$(tr '[:upper:]' '[:lower:]' <<< "${NAME:0:1}")${NAME:1}"
PACKAGE_MANIFEST="$ROOT/Packages/Features/Package.swift"
LOCALIZATION_CATALOG="$ROOT/Packages/Features/Sources/FeatureLocalization/Resources/Localizable.xcstrings"

# Validate shared mutation points before creating a single file.
/usr/bin/python3 -I - "$PACKAGE_MANIFEST" "$LOCALIZATION_CATALOG" "$NAME" <<'PY'
import json
import pathlib
import re
import sys

manifest_path = pathlib.Path(sys.argv[1])
catalog_path = pathlib.Path(sys.argv[2])
name = sys.argv[3]
manifest = manifest_path.read_text()

for marker in ("                // agent:app-feature-targets", "        // agent:feature-targets"):
    count = manifest.count(marker)
    if count != 1:
        raise SystemExit(f"expected one Package.swift marker {marker.strip()!r}, found {count}")
if re.search(rf'(?m)^\s*name:\s*"{re.escape(name)}"\s*,?$', manifest):
    raise SystemExit(f"Package.swift already declares {name}")
json.loads(catalog_path.read_text())
PY

mkdir -p "$SRC_DIR" "$TEST_DIR/__Snapshots__"
touch "$TEST_DIR/__Snapshots__/.gitkeep"

# --- Source templates (mirror the ItemList worked example) -------------------

cat > "$SRC_DIR/${NAME}Model.swift" <<EOF
import Domain
import Foundation
import Observation

@Observable
public final class ${NAME}Model {
    public enum Phase: Equatable {
        case loading
        case ready
        case failed(message: String)
    }

    public private(set) var phase: Phase = .loading

    public init() {}

    public func load() async {
        // TODO: inject stores via init and load real state.
        phase = .ready
    }
}

// MARK: - Preview & snapshot factories

public extension ${NAME}Model {
    static func preview(_ phase: Phase = .ready) -> ${NAME}Model {
        let model = ${NAME}Model()
        model.phase = phase
        return model
    }
}
EOF

cat > "$SRC_DIR/${NAME}View.swift" <<EOF
import DesignSystem
import SwiftUI

public struct ${NAME}View: View {
    @State private var model: ${NAME}Model
    private let loadsAutomatically: Bool

    public init(model: ${NAME}Model, loadsAutomatically: Bool = true) {
        _model = State(initialValue: model)
        self.loadsAutomatically = loadsAutomatically
    }

    public var body: some View {
        content
            .frame(minWidth: 640, minHeight: 420)
            .navigationTitle(${NAME}L10n.navigationTitle)
            .toolbar {
                ToolbarItem {
                    Button {
                        // TODO: perform the primary desktop action.
                    } label: {
                        Label(${NAME}L10n.primaryAction, systemImage: "plus")
                    }
                    .accessibilityIdentifier("${LOWER_NAME}.primaryAction")
                }
            }
            .task {
                if loadsAutomatically, model.phase == .loading {
                    await model.load()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("${LOWER_NAME}.loading")
        case let .failed(message):
            DSEmptyState(
                systemImage: "exclamationmark.triangle",
                title: ${NAME}L10n.errorTitle,
                message: message,
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("${LOWER_NAME}.error")
        case .ready:
            DSEmptyState(
                systemImage: "sparkles",
                title: ${NAME}L10n.readyTitle,
                message: ${NAME}L10n.readyMessage,
                actionTitle: ${NAME}L10n.primaryAction,
            ) {
                // TODO: perform the primary desktop action.
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("${LOWER_NAME}.placeholder")
        }
    }
}

#Preview("Loading") {
    NavigationSplitView {
        List(selection: .constant(0)) {
            Text(${NAME}L10n.navigationTitle).tag(0)
        }
        .listStyle(.sidebar)
    } detail: {
        ${NAME}View(model: .preview(.loading), loadsAutomatically: false)
    }
    .tint(.dsAccent)
}

#Preview("Ready") {
    NavigationSplitView {
        List(selection: .constant(0)) {
            Text(${NAME}L10n.navigationTitle).tag(0)
        }
        .listStyle(.sidebar)
    } detail: {
        ${NAME}View(model: .preview())
    }
    .tint(.dsAccent)
}

#Preview("Failed") {
    NavigationSplitView {
        List(selection: .constant(0)) {
            Text(${NAME}L10n.navigationTitle).tag(0)
        }
        .listStyle(.sidebar)
    } detail: {
        ${NAME}View(model: .preview(.failed(message: ${NAME}L10n.previewError)))
    }
    .tint(.dsAccent)
}
EOF

cat > "$SRC_DIR/${NAME}L10n.swift" <<EOF
import FeatureLocalization

enum ${NAME}L10n {
    static let navigationTitle = FeatureL10n.string("${LOWER_NAME}.navigation_title", default: "${NAME}")
    static let errorTitle = FeatureL10n.string("${LOWER_NAME}.error_title", default: "Something went wrong")
    static let readyTitle = FeatureL10n.string("${LOWER_NAME}.ready_title", default: "${NAME}")
    static let readyMessage = FeatureL10n.string(
        "${LOWER_NAME}.ready_message",
        default: "Replace this placeholder with the real macOS surface.",
    )
    static let primaryAction = FeatureL10n.string("${LOWER_NAME}.primary_action", default: "New")
    static let previewError = FeatureL10n.string("${LOWER_NAME}.preview_error", default: "Couldn't load.")
}
EOF

cat > "$TEST_DIR/${NAME}ModelTests.swift" <<EOF
import Testing
@testable import ${NAME}

@Suite("${NAME}Model")
struct ${NAME}ModelTests {
    @Test("Load reaches ready")
    func load() async {
        let model = ${NAME}Model()

        await model.load()

        #expect(model.phase == .ready)
    }
}
EOF

cat > "$TEST_DIR/${NAME}SnapshotTests.swift" <<EOF
#if os(macOS) && SNAPSHOT_TESTS
    import DesignSystem
    import SnapshotSupport
    import SwiftUI
    import Testing
    @testable import ${NAME}

    @Suite("${NAME} screens", .serialized)
    struct ${NAME}SnapshotTests {
        private func screen(_ state: ${NAME}Model.Phase = .ready) -> some View {
            DesktopSnapshotShell {
                List(selection: .constant(0)) {
                    Text(${NAME}L10n.navigationTitle).tag(0)
                }
                .listStyle(.sidebar)
            } detail: {
                ${NAME}View(model: .preview(state), loadsAutomatically: false)
            }
        }

        @Test func loading() {
            assertScreenSnapshot(of: screen(.loading))
        }

        @Test func ready() {
            assertScreenSnapshot(of: screen())
        }

        @Test func failed() {
            assertScreenSnapshot(of: screen(.failed(message: ${NAME}L10n.previewError)))
        }
    }

    private struct DesktopSnapshotShell<Sidebar: View, Detail: View>: View {
        let sidebar: Sidebar
        let detail: Detail

        init(
            @ViewBuilder sidebar: () -> Sidebar,
            @ViewBuilder detail: () -> Detail,
        ) {
            self.sidebar = sidebar()
            self.detail = detail()
        }

        var body: some View {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 280)
                    .background(.regularMaterial)

                Divider()

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.dsBackground)
            }
            .frame(width: 1000, height: 700)
            .tint(.dsAccent)
        }
    }
#endif
EOF

# --- Wire into Packages/Features/Package.swift at the agent markers ----------

/usr/bin/python3 -I - "$ROOT/Packages/Features/Package.swift" "$NAME" <<'PY'
import sys

path, name = sys.argv[1], sys.argv[2]
text = open(path).read()

product_marker = "                // agent:app-feature-targets"
target_marker = "        // agent:feature-targets"
assert product_marker in text and target_marker in text, "agent markers missing from Package.swift"

product_target = f'                "{name}",\n'
targets = f'''        .target(
            name: "{name}",
            dependencies: [
                "FeatureLocalization",
                .product(name: "Domain", package: "Domain"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            swiftSettings: featureSettings,
        ),
        .testTarget(
            name: "{name}Tests",
            dependencies: [
                "{name}",
                .product(name: "SnapshotSupport", package: "TestSupport"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: featureSettings,
        ),
'''

text = text.replace(product_marker, product_target + product_marker)
text = text.replace(target_marker, targets + target_marker)
open(path, "w").write(text)
print(f"Package.swift: added {name} to AppFeatures + targets")
PY

/usr/bin/python3 -I - "$ROOT/Packages/Features/Sources/FeatureLocalization/Resources/Localizable.xcstrings" "$LOWER_NAME" "$NAME" <<'PY'
import json
import sys

path, lower_name, name = sys.argv[1:4]
with open(path) as file:
    catalog = json.load(file)

strings = catalog.setdefault("strings", {})

def add(key, value):
    strings.setdefault(
        key,
        {
            "localizations": {
                "en": {
                    "stringUnit": {
                        "state": "translated",
                        "value": value,
                    }
                }
            }
        },
    )

add(f"{lower_name}.navigation_title", name)
add(f"{lower_name}.error_title", "Something went wrong")
add(f"{lower_name}.ready_title", name)
add(f"{lower_name}.ready_message", "Replace this placeholder with the real macOS surface.")
add(f"{lower_name}.primary_action", "New")
add(f"{lower_name}.preview_error", "Couldn't load.")

with open(path, "w") as file:
    json.dump(catalog, file, indent=2, sort_keys=True)
    file.write("\n")

print(f"Localizable.xcstrings: seeded keys for {name}")
PY

echo
echo "Feature $NAME scaffolded. Next steps:"
echo "  1. scripts/test.sh Features"
echo "  2. Add real model/store behavior before replacing placeholder UI"
echo "  3. scripts/snapshot.sh Features ${NAME}Tests"
echo "  4. Wire into RootView/commands/settings as the product needs"
