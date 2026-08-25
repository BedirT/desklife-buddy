import Testing

@testable import ObservablePreviewWiring

/// The rule under test, stated once: an Optional property on an `@Observable`
/// model is a violation when preview-only sources assign it a non-nil value and
/// no shipping source does. Every other shape is deliberately silent - this is a
/// syntactic contract, not a proof that no runtime writer exists.
@Suite struct AnalyzerTests {
    // MARK: - The #64 shape

    @Test func flagsStoredStateWrittenOnlyByPreviews() {
        let findings = analyze([
            .shipping(
                "Packages/Features/Sources/Review/ReviewModel.swift",
                """
                @Observable
                public final class ReviewModel {
                    public var shareProgress: ShareProgress?
                }
                """,
            ),
            .preview(
                "Packages/Features/Sources/Review/ReviewGalleryView+Previews.swift",
                """
                func make(_ model: ReviewModel) {
                    model.shareProgress = .init(fraction: 0.62)
                }
                """,
            ),
        ])

        #expect(findings.count == 1)
        #expect(findings.first?.model == "ReviewModel")
        #expect(findings.first?.property == "shareProgress")
        #expect(findings.first?.line == 3)
        #expect(
            findings.first?.previewWriters
                == ["Packages/Features/Sources/Review/ReviewGalleryView+Previews.swift:2"],
        )
    }

    /// The regression that blocked the previous attempt: the motivating property
    /// is computed over private storage, and a lexical stored-property scan
    /// skipped it entirely.
    @Test func flagsComputedStateWrittenOnlyByPreviews() {
        let findings = analyze([
            .shipping(
                "Packages/Features/Sources/Review/ReviewModel.swift",
                """
                @Observable
                public final class ReviewModel {
                    private var publishedShareProgress: ShareProgress?
                    public var shareProgress: ShareProgress? {
                        get { publishedShareProgress }
                        set { publishedShareProgress = newValue }
                    }
                }
                """,
            ),
            .preview(
                "Packages/Features/Sources/Review/ReviewGalleryView+Previews.swift",
                "let model = ReviewModel.preview(.photo)\nmodel.shareProgress = .init(fraction: 0.62)",
            ),
        ])

        #expect(findings.map(\.property) == ["shareProgress"])
    }

    /// The setter's own write to the backing store is plumbing, not reachability.
    /// Counting it would make every computed property permanently green.
    @Test func setterWriteToBackingStorageIsNotAShippingWriter() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    private var storage: Int?
                    var value: Int? {
                        get { storage }
                        set { storage = newValue }
                    }
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 3"),
        ])

        #expect(findings.map(\.property) == ["value"])
    }

    /// ...but a shipping writer that goes straight to the backing store does
    /// make the state reachable, and must silence the finding.
    @Test func shippingWriteToBackingStorageCounts() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    private var storage: Int?
                    var value: Int? {
                        get { storage }
                        set { storage = newValue }
                    }
                    func load() { storage = 7 }
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 3"),
        ])

        #expect(findings.isEmpty)
    }

    /// A default on the *backing* store makes the computed property non-nil from
    /// the moment the model exists, exactly as a default on the property itself
    /// would. Reading only the computed declaration invents a violation.
    @Test func nonNilDefaultOnBackingStorageMakesStateReachable() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    private var storage: Int? = 3
                    var value: Int? {
                        get { storage }
                        set { storage = newValue }
                    }
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 4"),
        ])

        #expect(findings.isEmpty)
    }

    /// Backing storage that is not itself Optional always holds a value.
    @Test func nonOptionalBackingStorageMakesStateReachable() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    private var storage: Int = 0
                    var value: Int? {
                        get { storage }
                        set { storage = newValue ?? 0 }
                    }
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 4"),
        ])

        #expect(findings.isEmpty)
    }

    // MARK: - Preview regions inside shipping files

    /// `check-previews.sh` requires a `#Preview` in every view file, so most
    /// preview code in this repo lives in shipping sources. A write inside one
    /// is a preview writer; counting it as shipping silences the finding in
    /// precisely the files the convention guarantees exist.
    @Test func writeInsideAnInlinePreviewIsAPreviewWriter() {
        let findings = analyze([
            .shipping(
                "ReviewView.swift",
                """
                @Observable
                final class ReviewModel {
                    var shareProgress: Progress?
                }

                #Preview("progress") {
                    let model = ReviewModel()
                    model.shareProgress = .init(fraction: 0.5)
                    return ReviewView(model: model)
                }
                """,
            ),
        ])

        #expect(findings.map(\.property) == ["shareProgress"])
        #expect(findings.first?.previewWriters == ["ReviewView.swift:8"])
    }

    @Test func writeOutsideThePreviewInTheSameFileStillCounts() {
        let findings = analyze([
            .shipping(
                "ReviewView.swift",
                """
                @Observable
                final class ReviewModel {
                    var shareProgress: Progress?
                    func begin() { shareProgress = .init(fraction: 0) }
                }

                #Preview("progress") {
                    let model = ReviewModel()
                    model.shareProgress = .init(fraction: 0.5)
                    return ReviewView(model: model)
                }
                """,
            ),
        ])

        #expect(findings.isEmpty)
    }

    // MARK: - Receiver attribution

    /// Writes are matched by name, so an unrelated helper assigning its own
    /// `value` must not be attributed to a model that happens to declare one.
    @Test func previewWriteOnAResolvedForeignTypeIsNotAttributed() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var value: Int?
                }
                """,
            ),
            .preview(
                "HistoryPreviewLibrary.swift",
                """
                func seed(model: Model) {
                    var random = SeededRandom(seed: 1)
                    random.value = 3
                }
                """,
            ),
        ])

        #expect(findings.isEmpty)
    }

    /// A preview source that never mentions the model cannot be writing to it.
    @Test func previewWriteInAFileThatNeverNamesTheModelIsNotAttributed() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var value: Int?
                }
                """,
            ),
            .preview("OtherPreviewData.swift", "fixture.value = 3"),
        ])

        #expect(findings.isEmpty)
    }

    /// A receiver that resolves to nothing is unknown, and unknown must not
    /// produce a lint failure - even in a file that names the model.
    @Test func previewWriteOnAnUnresolvedReceiverIsNotAttributed() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var value: Int?
                }
                """,
            ),
            .preview(
                "Model+Previews.swift",
                """
                func make() -> Model {
                    let fixture = untypedFactory()
                    fixture.value = 3
                    return fixture
                }
                """,
            ),
        ])

        #expect(findings.isEmpty)
    }

    /// The motivating fixture builds its model through a static factory, which
    /// is the shape that has to keep resolving.
    @Test func previewWriteOnAFactoryBuiltModelIsAttributed() {
        let findings = analyze([
            .shipping(
                "ReviewModel.swift",
                """
                @Observable
                public final class ReviewModel {
                    public var shareProgress: ShareProgress?
                }
                """,
            ),
            .preview(
                "ReviewGalleryView+Previews.swift",
                """
                var body: some View {
                    let model = ReviewModel.preview(state)
                    if let shareProgress { model.shareProgress = shareProgress }
                    return ReviewGalleryView(model: model)
                }
                """,
            ),
        ])

        #expect(findings.map(\.property) == ["shareProgress"])
    }

    // MARK: - Spelled-out nil

    @Test func qualifiedOptionalNoneIsNil() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var value: Int? = Optional<Int>.none
                    func clear() { value = .none }
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 3"),
        ])

        #expect(findings.map(\.property) == ["value"])
    }

    @Test func qualifiedOptionalNoneIsNotAPreviewWriter() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var value: Int?
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = Optional<Int>.none"),
        ])

        #expect(findings.isEmpty)
    }

    // MARK: - Silence where the rule cannot prove anything

    @Test func shippingWriterInAnotherTreeSilencesTheFinding() {
        let findings = analyze([
            .shipping(
                "Packages/Features/Sources/Review/ReviewModel.swift",
                """
                @Observable
                public final class ReviewModel {
                    public var shareProgress: ShareProgress?
                }
                """,
            ),
            .shipping(
                "App/AppCompositionModel+ReviewSharing.swift",
                "reviewModel.shareProgress = .init(fraction: 0, isIndeterminate: true)",
            ),
            .preview(
                "Packages/Features/Sources/Review/ReviewGalleryView+Previews.swift",
                "let model = ReviewModel.preview(.photo)\nmodel.shareProgress = .init(fraction: 0.62)",
            ),
        ])

        #expect(findings.isEmpty)
    }

    /// No preview writer means no evidence of the #64 shape. State that is only
    /// ever reachable through injected app state lands here, which is why the
    /// rule can be blocking without an exemption for every such property.
    @Test func stateWithNoWritersAtAllIsNotFlagged() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var injected: Int?
                }
                """,
            ),
        ])

        #expect(findings.isEmpty)
    }

    @Test func nilAssignmentsAreNotWriters() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var value: Int?
                    func clear() { value = nil }
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 3"),
        ])

        #expect(findings.map(\.property) == ["value"])
    }

    @Test func conditionalShippingWriteCountsAsNonNil() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var value: Int?
                    func refresh(_ limited: Bool) { value = limited ? count : nil }
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 3"),
        ])

        #expect(findings.isEmpty)
    }

    @Test func nonOptionalStateIsIgnored() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var value: Int = 0
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 3"),
        ])

        #expect(findings.isEmpty)
    }

    @Test func nonObservableTypesAreIgnored() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                final class Model {
                    var value: Int?
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 3"),
        ])

        #expect(findings.isEmpty)
    }

    @Test func nonNilDefaultMakesStateReachable() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var value: Int? = 3
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 4"),
        ])

        #expect(findings.isEmpty)
    }

    /// Two models declaring the same property name make every unqualified write
    /// ambiguous. The rule refuses to guess rather than report a coin flip.
    @Test func ambiguousPropertyNamesAreSkipped() {
        let findings = analyze([
            .shipping(
                "A.swift",
                """
                @Observable
                final class A {
                    var value: Int?
                }
                """,
            ),
            .shipping(
                "B.swift",
                """
                @Observable
                final class B {
                    var value: Int?
                }
                """,
            ),
            .preview("A+Previews.swift", "a.value = 3"),
        ])

        #expect(findings.isEmpty)
    }

    @Test func didSetObserverIsStoredNotComputed() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var value: Int? {
                        didSet { log(value) }
                    }
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 3"),
        ])

        #expect(findings.map(\.property) == ["value"])
    }

    @Test func staticStateIsIgnored() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    static var shared: Int?
                }
                """,
            ),
            .preview("Model+Previews.swift", "Model.shared = 3"),
        ])

        #expect(findings.isEmpty)
    }

    @Test func modelsDeclaredInPreviewSourcesAreIgnored() {
        let findings = analyze([
            .preview(
                "ReviewPreviewData.swift",
                """
                @Observable
                final class FixtureModel {
                    var value: Int?
                    func seed() { value = 3 }
                }
                """,
            ),
        ])

        #expect(findings.isEmpty)
    }

    // MARK: - Exemptions

    @Test func exemptionWithAReasonSilencesTheFinding() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    // observable-preview-wiring-exempt: set by the Photos delegate callback.
                    var value: Int?
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 3"),
        ])

        #expect(findings.isEmpty)
    }

    @Test func trailingExemptionCommentIsHonored() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    var value: Int? // observable-preview-wiring-exempt: delegate callback.
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 3"),
        ])

        #expect(findings.isEmpty)
    }

    /// An exemption without a stated reason is the failure mode the marker
    /// exists to prevent, so it is itself a violation.
    @Test func exemptionWithoutAReasonIsAViolation() {
        let findings = analyze([
            .shipping(
                "Model.swift",
                """
                @Observable
                final class Model {
                    // observable-preview-wiring-exempt:
                    var value: Int?
                }
                """,
            ),
            .preview("Model+Previews.swift", "let model = Model()\nmodel.value = 3"),
        ])

        #expect(findings.map(\.kind) == [.emptyExemptionReason])
    }

    // MARK: - Source classification

    @Test func previewSourcesAreRecognizedByName() {
        #expect(SourceFile.isPreviewOnly(path: "a/b/ReviewGalleryView+Previews.swift"))
        #expect(SourceFile.isPreviewOnly(path: "a/b/ReviewPreviewData.swift"))
        #expect(SourceFile.isPreviewOnly(path: "a/b/DSPreviewLibrary.swift"))
        #expect(SourceFile.isPreviewOnly(path: "a/b/PreviewFixtures.swift"))
        #expect(!SourceFile.isPreviewOnly(path: "a/b/ReviewGalleryView.swift"))
        #expect(!SourceFile.isPreviewOnly(path: "a/b/ReviewModel.swift"))
    }

    // MARK: - Helpers

    private func analyze(_ files: [SourceFile]) -> [Finding] {
        Analyzer.analyze(files)
    }
}

private extension SourceFile {
    static func shipping(_ path: String, _ text: String) -> SourceFile {
        SourceFile(path: path, text: text, isPreviewOnly: false)
    }

    static func preview(_ path: String, _ text: String) -> SourceFile {
        SourceFile(path: path, text: text, isPreviewOnly: true)
    }
}
