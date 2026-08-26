#if os(macOS)
    import Foundation

    func snapshotBaselineIdentity(
        fileID: String,
        filePath: String,
        testName: String,
        snapshotName: String,
    ) -> String? {
        let fileIDComponents = fileID.split(separator: "/", omittingEmptySubsequences: false)
        guard fileIDComponents.count == 2 else {
            return nil
        }

        let target = String(fileIDComponents[0])
        var pathComponents = URL(fileURLWithPath: filePath).standardizedFileURL.pathComponents
        guard let testsIndex = pathComponents.indices.reversed().first(where: { index in
            pathComponents[index] == "Tests"
                && pathComponents.indices.contains(index + 1)
                && pathComponents[index + 1] == target
        }) else {
            return nil
        }

        pathComponents = Array(pathComponents.dropFirst(testsIndex + 2))
        guard let sourceFile = pathComponents.popLast(), !pathComponents.contains("__Snapshots__") else {
            return nil
        }
        let sourceName = URL(fileURLWithPath: sourceFile).deletingPathExtension().lastPathComponent
        let testComponent = snapshotPathComponent(testName)
        let snapshotComponent = snapshotPathComponent(snapshotName)
        guard !sourceName.isEmpty, !testComponent.isEmpty, !snapshotComponent.isEmpty else {
            return nil
        }

        let sourceComponents = [target] + pathComponents + [sourceName]
        return "\(sourceComponents.joined(separator: "/"))/\(testComponent).\(snapshotComponent)"
    }

    func snapshotSafeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar).description : "-"
        }
        .joined()
        .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    func snapshotBaselineURL(
        filePath: String,
        testName: String,
        snapshotName: String,
    ) -> URL? {
        let sourceURL = URL(fileURLWithPath: filePath)
        let sourceName = sourceURL.deletingPathExtension().lastPathComponent
        let testComponent = snapshotPathComponent(testName)
        let snapshotComponent = snapshotPathComponent(snapshotName)
        guard !sourceName.isEmpty, !testComponent.isEmpty, !snapshotComponent.isEmpty else {
            return nil
        }
        return sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__", isDirectory: true)
            .appendingPathComponent(sourceName, isDirectory: true)
            .appendingPathComponent("\(testComponent).\(snapshotComponent).png")
    }

    struct SnapshotExportMetadata {
        let baselineIdentity: String
        let displayName: String
        let group: String
        let verificationMode: String
        let testName: String
        let fileIdentity: String
        let pixelWidth: Int
        let pixelHeight: Int
        let pointWidth: Double
        let pointHeight: Double
        let backingScaleFactor: Double

        var dictionary: [String: Any] {
            [
                "baseline_identity": baselineIdentity,
                "display_name": displayName,
                "group": group,
                "verification_mode": verificationMode,
                "context": [
                    "test_name": testName,
                    "file_id": fileIdentity,
                    "platform": "macOS",
                ],
                "render": [
                    "pixel_width": pixelWidth,
                    "pixel_height": pixelHeight,
                    "point_width": pointWidth,
                    "point_height": pointHeight,
                    "backing_scale_factor": backingScaleFactor,
                ],
            ]
        }
    }

    private func snapshotPathComponent(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
    }
#endif
