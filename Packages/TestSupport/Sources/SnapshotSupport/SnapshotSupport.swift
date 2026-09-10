#if os(macOS)
    import AppKit
    import ImageIO
    import SwiftUI
    import Testing

    /// Deterministic SwiftUI snapshot helpers. Every snapshot in this repo goes through here
    /// so determinism is enforced in one place:
    ///
    /// - Fixed desktop window metrics for full-window renders (1000x700 pt).
    /// - Fixed 2x backing scale and Display P3 color space on every machine.
    /// - Frozen locale (en_US), time zone (UTC), and calendar.
    /// - Light/dark appearances are driven through NSAppearance on the host view.
    /// - Snapshot PNGs are also exported to SNAPSHOTS_EXPORT_DIR for direct
    ///   inspection under `artifacts/preview-review/`.
    /// - Recording: a missing baseline records itself on first run. Replacing
    ///   an existing baseline requires the `.snapshot-record-token` directory,
    ///   which is owned by `scripts/record-snapshots.sh --confirm`.

    public enum SnapshotLayout {
        /// Full desktop window render at 1000x700 pt.
        case window
        /// Exact-size render for accepted fixed-canvas compositions.
        case fixed(width: CGFloat, height: CGFloat)
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
    ) {
        for appearance in appearances {
            let snapshotName = name.map { "\($0)-\(appearance.rawValue)" } ?? appearance.rawValue
            let host = hostedSnapshot(
                for: view,
                layout: layout,
                appearance: appearance,
                fileKey: "\(filePath)",
            )
            defer { host.close() }
            export(
                host.view,
                name: snapshotName,
                group: testName,
                fileID: fileID,
                filePath: filePath,
            )
            assertPixelBaseline(
                of: host.view,
                named: snapshotName,
                filePath: filePath,
                testName: testName,
            )
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
    ) {
        for size in sizes {
            let snapshotName = name.map { "\($0)-\(size)" } ?? "\(size)"
            let host = hostedSnapshot(
                for: frozen(view)
                    .environment(\.dynamicTypeSize, size),
                layout: layout,
                appearance: .light,
                fileKey: "\(filePath)",
            )
            defer { host.close() }
            export(
                host.view,
                name: snapshotName,
                group: testName,
                fileID: fileID,
                filePath: filePath,
            )
            assertPixelBaseline(
                of: host.view,
                named: snapshotName,
                filePath: filePath,
                testName: testName,
            )
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
    #elseif SNAPSHOT_TESTS && SNAPSHOT_BASELINE_VERIFICATION
        private let compiledVerificationMode = "baseline"
    #elseif SNAPSHOT_TESTS
        #error("SnapshotSupport requires an explicit snapshot verification mode")
    #else
        private let compiledVerificationMode = "inactive"
    #endif

    private final class HostedSnapshot {
        let view: NSView
        private let window: NSWindow

        init(
            rootView: some View,
            layout: SnapshotLayout,
            appearance: SnapshotAppearance,
            fileKey: String,
        ) {
            let controller = NSHostingController(rootView: AnyView(rootView))

            let size: CGSize
            switch layout {
            case .window:
                size = CGSize(width: 1000, height: 700)
            case let .fixed(width, height):
                size = CGSize(width: width, height: height)
            case .sizeThatFits:
                let fitting = controller.view.fittingSize
                size = CGSize(width: max(fitting.width, 1), height: max(fitting.height, 1))
            }

            let frame = NSRect(origin: .zero, size: size)
            // One window per test file and size: any cross-suite reuse lets
            // earlier suites' backing-store/appearance residue bleed into later
            // captures, while deallocating windows crashes (SwiftUI hosting
            // teardown). File-scoped pooling bounds window count; content is
            // detached on close.
            let key = "\(fileKey)-\(Int(size.width))x\(Int(size.height))"
            let window: NSWindow
            if let pooled = snapshotWindowPool[key] {
                window = pooled
            } else {
                window = SnapshotWindow(contentRect: frame)
                snapshotWindowPool[key] = window
            }
            window.appearance = appearance.nsAppearance
            window.contentViewController = controller
            window.setFrame(frame, display: true)
            controller.view.frame = frame
            controller.view.layoutSubtreeIfNeeded()
            window.layoutIfNeeded()
            window.displayIfNeeded()
            self.window = window
            view = controller.view
        }

        func close() {
            window.contentViewController = nil
        }
    }

    private var snapshotWindowPool: [String: NSWindow] = [:]

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
        fileKey: String,
    ) -> HostedSnapshot {
        let rootView = frozen(view)
            .environment(\.colorScheme, appearance.colorScheme)
        return HostedSnapshot(
            rootView: rootView,
            layout: layout,
            appearance: appearance,
            fileKey: fileKey,
        )
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

    private func assertPixelBaseline(
        of view: NSView,
        named name: String,
        filePath: StaticString,
        testName: String,
    ) {
        guard compiledVerificationMode == "baseline",
              let render = pngRender(for: view),
              let baselineURL = snapshotBaselineURL(
                  filePath: "\(filePath)",
                  testName: testName,
                  snapshotName: name,
              )
        else {
            return
        }

        do {
            if isRecordModeRequested(file: filePath) || !FileManager.default.fileExists(atPath: baselineURL.path) {
                try FileManager.default.createDirectory(
                    at: baselineURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                )
                try render.data.write(to: baselineURL, options: .atomic)
                return
            }

            let expected = try Data(contentsOf: baselineURL)
            guard let expectedPixels = normalizedPixels(expected),
                  let currentPixels = normalizedPixels(render.data)
            else {
                Issue.record("Snapshot PNG could not be decoded: \(baselineURL.path)")
                return
            }
            guard expectedPixels == currentPixels else {
                Issue.record("Snapshot mismatch: \(baselineURL.path)")
                return
            }
        } catch {
            Issue.record("Snapshot baseline failed: \(error)")
        }
    }

    private struct PixelBuffer: Equatable {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }

    private func normalizedPixels(_ data: Data) -> PixelBuffer? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(
                  data: &bytes,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
              )
        else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return PixelBuffer(width: width, height: height, bytes: bytes)
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
