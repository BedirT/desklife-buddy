#if os(macOS)
    import AppKit
    import SnapshotTesting
    import SwiftUI
    import Testing

    /// Deterministic SwiftUI snapshot helpers. Every snapshot in this repo goes through here
    /// so determinism is enforced in one place:
    ///
    /// - Fixed desktop window metrics for full-window renders (1000x700 pt).
    /// - Fixed 2x backing scale and Display P3 color space on every machine.
    /// - Frozen locale (en_US), time zone (UTC), and calendar.
    /// - Light/dark appearances are driven through NSAppearance on the host view.
    /// - Snapshot PNGs are also exported to SNAPSHOTS_EXPORT_DIR for the
    ///   owner-facing `artifacts/preview-review/` contact sheet.
    /// - Recording: a *missing* baseline records itself on first run. Failed
    ///   existing baselines are captured for the colored diff review and are
    ///   accepted byte-for-byte with scripts/accept-snapshots.sh. Bulk fallback
    ///   recording requires the `.snapshot-record-token` lock directory.

    public enum SnapshotLayout {
        /// Full desktop window render at 1000x700 pt.
        case window
        /// Tight render for components; the view defines its own size.
        case sizeThatFits
    }

    public enum SnapshotAppearance: String, CaseIterable {
        case light
        case dark

        var nsAppearance: NSAppearance? {
            switch self {
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            }
        }

        var colorScheme: ColorScheme {
            switch self {
            case .light: .light
            case .dark: .dark
            }
        }
    }

    public func assertScreenSnapshot(
        of view: some View,
        named name: String? = nil,
        layout: SnapshotLayout = .window,
        appearances: [SnapshotAppearance] = [.light, .dark],
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column,
    ) {
        withRecordMode(file: filePath) {
            for appearance in appearances {
                let snapshotName = name.map { "\($0)-\(appearance.rawValue)" } ?? appearance.rawValue
                let host = hostedSnapshot(for: view, layout: layout, appearance: appearance)
                defer { host.close() }
                export(
                    host.view,
                    name: snapshotName,
                    group: testName,
                    fileID: fileID,
                    filePath: filePath,
                )
                if verifiesPixelBaselines {
                    assertSnapshot(
                        of: host.view,
                        as: .image(precision: 1, perceptualPrecision: 0.98),
                        named: snapshotName,
                        fileID: fileID,
                        file: filePath,
                        testName: testName,
                        line: line,
                        column: column,
                    )
                }
            }
        }
    }

    public func assertDynamicTypeSnapshot(
        of view: some View,
        named name: String? = nil,
        sizes: [DynamicTypeSize] = [.accessibility3],
        layout: SnapshotLayout = .window,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column,
    ) {
        withRecordMode(file: filePath) {
            for size in sizes {
                let snapshotName = name.map { "\($0)-\(size)" } ?? "\(size)"
                let host = hostedSnapshot(
                    for: frozen(view).environment(\.dynamicTypeSize, size),
                    layout: layout,
                    appearance: .light,
                )
                defer { host.close() }
                export(
                    host.view,
                    name: snapshotName,
                    group: testName,
                    fileID: fileID,
                    filePath: filePath,
                )
                if verifiesPixelBaselines {
                    assertSnapshot(
                        of: host.view,
                        as: .image(precision: 1, perceptualPrecision: 0.98),
                        named: snapshotName,
                        fileID: fileID,
                        file: filePath,
                        testName: testName,
                        line: line,
                        column: column,
                    )
                }
            }
        }
    }

    private func frozen(_ view: some View) -> some View {
        view
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.timeZone, TimeZone(identifier: "UTC") ?? .current)
            .environment(\.calendar, Calendar(identifier: .gregorian))
    }

    #if SNAPSHOT_TESTS && SNAPSHOT_RENDER_ONLY && SNAPSHOT_BASELINE_VERIFICATION
        #error("SnapshotSupport cannot compile with two verification modes")
    #elseif SNAPSHOT_TESTS && SNAPSHOT_RENDER_ONLY
        private let compiledVerificationMode = "render-only"
        private let verifiesPixelBaselines = false
    #elseif SNAPSHOT_TESTS && SNAPSHOT_BASELINE_VERIFICATION
        private let compiledVerificationMode = "baseline"
        private let verifiesPixelBaselines = true
    #elseif SNAPSHOT_TESTS
        #error("SnapshotSupport requires an explicit snapshot verification mode")
    #else
        private let compiledVerificationMode = "inactive"
        private let verifiesPixelBaselines = true
    #endif

    private final class HostedSnapshot {
        let view: NSView

        init(rootView: some View, layout: SnapshotLayout, appearance: SnapshotAppearance) {
            let controller = NSHostingController(rootView: AnyView(rootView))

            let size: CGSize
            switch layout {
            case .window:
                size = CGSize(width: 1000, height: 700)
            case .sizeThatFits:
                let fitting = controller.view.fittingSize
                size = CGSize(width: max(fitting.width, 1), height: max(fitting.height, 1))
            }

            let frame = NSRect(origin: .zero, size: size)
            let window = reusableSnapshotWindow(frame: frame)
            window.appearance = appearance.nsAppearance
            window.contentViewController = controller
            window.setFrame(frame, display: true)
            controller.view.frame = frame
            controller.view.layoutSubtreeIfNeeded()
            window.layoutIfNeeded()
            window.displayIfNeeded()
            snapshotController = controller
            view = controller.view
        }

        func close() {
            // Keep one reusable offscreen window alive for AppKit stability.
        }
    }

    private var snapshotWindow: NSWindow?
    private var snapshotController: NSHostingController<AnyView>?

    private func reusableSnapshotWindow(frame: NSRect) -> NSWindow {
        if let snapshotWindow {
            return snapshotWindow
        }

        let window = SnapshotWindow(contentRect: frame)
        snapshotWindow = window
        return window
    }

    private final class SnapshotWindow: NSWindow {
        private let snapshotBackingScaleFactor: CGFloat = 2
        private let snapshotColorSpace: NSColorSpace? = .displayP3
        private var systemColorSpace: NSColorSpace?

        init(contentRect: NSRect) {
            super.init(
                contentRect: contentRect,
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false,
            )
        }

        override var backingScaleFactor: CGFloat {
            snapshotBackingScaleFactor
        }

        override var colorSpace: NSColorSpace? {
            get { snapshotColorSpace ?? systemColorSpace }
            set { systemColorSpace = newValue }
        }
    }

    private func hostedSnapshot(
        for view: some View,
        layout: SnapshotLayout,
        appearance: SnapshotAppearance,
    ) -> HostedSnapshot {
        let rootView = frozen(view)
            .environment(\.colorScheme, appearance.colorScheme)
        return HostedSnapshot(rootView: rootView, layout: layout, appearance: appearance)
    }

    private func export(
        _ view: NSView,
        name: String,
        group: String,
        fileID: StaticString,
        filePath: StaticString,
    ) {
        guard let exportPath = ProcessInfo.processInfo.environment["SNAPSHOTS_EXPORT_DIR"],
              !exportPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        let exportURL = URL(fileURLWithPath: exportPath, isDirectory: true)
        let fileIdentity = "\(fileID)"
        let exportGroup = "\(fileIdentity) / \(group)"
        let baseName = snapshotSafeFileName("\(fileIdentity)-\(group)-\(name)")
        let imageURL = exportURL.appendingPathComponent("\(baseName).png")
        let sidecarURL = exportURL.appendingPathComponent("\(baseName).json")

        do {
            try FileManager.default.createDirectory(at: exportURL, withIntermediateDirectories: true)
            guard let render = pngRender(for: view) else {
                Issue.record("SnapshotSupport could not render PNG export '\(baseName)'.")
                return
            }
            guard let baselineIdentity = snapshotBaselineIdentity(
                fileID: fileIdentity,
                filePath: "\(filePath)",
                testName: group,
                snapshotName: name,
            ) else {
                Issue.record("SnapshotSupport could not establish baseline identity for '\(baseName)'.")
                return
            }
            try render.data.write(to: imageURL, options: .atomic)
            let metadata = SnapshotExportMetadata(
                baselineIdentity: baselineIdentity,
                displayName: name,
                group: exportGroup,
                verificationMode: compiledVerificationMode,
                testName: group,
                fileIdentity: fileIdentity,
                pixelWidth: render.pixelWidth,
                pixelHeight: render.pixelHeight,
                pointWidth: render.pointWidth,
                pointHeight: render.pointHeight,
                backingScaleFactor: render.backingScaleFactor,
            ).dictionary
            let metadataData = try JSONSerialization.data(
                withJSONObject: metadata,
                options: [.prettyPrinted, .sortedKeys],
            )
            try metadataData.write(to: sidecarURL, options: .atomic)
        } catch {
            Issue.record("SnapshotSupport export '\(baseName)' failed: \(error)")
        }
    }

    private struct PNGRender {
        let data: Data
        let pixelWidth: Int
        let pixelHeight: Int
        let pointWidth: Double
        let pointHeight: Double
        let backingScaleFactor: Double
    }

    private func pngRender(for view: NSView) -> PNGRender? {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds),
              let window = view.window,
              window.backingScaleFactor > 0
        else {
            return nil
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return PNGRender(
            data: data,
            pixelWidth: bitmap.pixelsWide,
            pixelHeight: bitmap.pixelsHigh,
            pointWidth: Double(view.bounds.width),
            pointHeight: Double(view.bounds.height),
            backingScaleFactor: Double(window.backingScaleFactor),
        )
    }

    private func withRecordMode(file filePath: StaticString, _ operation: () -> Void) {
        if isRecordModeRequested(file: filePath) {
            withSnapshotTesting(record: .failed, operation: operation)
        } else {
            withSnapshotTesting(record: .missing, operation: operation)
        }
    }

    private func isRecordModeRequested(file filePath: StaticString) -> Bool {
        var directory = URL(fileURLWithPath: "\(filePath)").deletingLastPathComponent()
        let fileManager = FileManager.default

        while true {
            let gitEntry = directory.appendingPathComponent(".git").path
            if fileManager.fileExists(atPath: gitEntry) {
                let token = directory.appendingPathComponent(".snapshot-record-token").path
                let attributes = try? fileManager.attributesOfItem(atPath: token)
                return attributes?[.type] as? FileAttributeType == .typeDirectory
            }

            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path {
                return false
            }
            directory = parent
        }
    }
#endif
