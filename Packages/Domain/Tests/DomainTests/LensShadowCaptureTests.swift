import Foundation
import Testing
@testable import Domain

@Suite("Lens shadow capture (RED)")
struct LensShadowCaptureTests {
    @Test("Capture caps are 480p at 2fps")
    func captureCaps() {
        #expect(LensShadowCaptureCaps.maxWidth == 640)
        #expect(LensShadowCaptureCaps.maxHeight == 480)
        #expect(LensShadowCaptureCaps.maxFramesPerSecond == 2)
    }

    @Test("Session requires explicit per-session opt-in")
    func perSessionOptIn() {
        var pipeline = LensShadowCapturePipeline()
        #expect(!pipeline.isSessionActive)

        pipeline.startSession(consented: false, atTick: 0)
        #expect(!pipeline.isSessionActive)

        pipeline.startSession(consented: true, atTick: 1)
        #expect(pipeline.isSessionActive)
    }

    @Test("No frame survives its tick")
    func frameLifetime() {
        var pipeline = LensShadowCapturePipeline()
        pipeline.startSession(consented: true, atTick: 0)
        pipeline.ingest(LensShadowMemoryFrame(tick: 0))
        #expect(pipeline.liveFrameCount == 1)

        pipeline.endTick(0)

        #expect(pipeline.liveFrameCount == 0)
    }

    @Test("Stop drops the live frame and ends the session")
    func stopDropsFrame() {
        var pipeline = LensShadowCapturePipeline()
        pipeline.startSession(consented: true, atTick: 0)
        pipeline.ingest(LensShadowMemoryFrame(tick: 0))

        pipeline.stop()

        #expect(!pipeline.isSessionActive)
        #expect(pipeline.liveFrameCount == 0)
    }

    @Test("Thermal pressure sheds first (degrade-first)")
    func degradeFirst() {
        var pipeline = LensShadowCapturePipeline()
        pipeline.startSession(consented: true, atTick: 0)
        pipeline.ingest(LensShadowMemoryFrame(tick: 0), thermal: .critical)

        #expect(pipeline.liveFrameCount == 0)
        #expect(pipeline.framesShed == 1)
    }

    @Test("Inspector exposes counts only — no frames, embeddings, or pixels")
    func inspectorCountsOnly() {
        var pipeline = LensShadowCapturePipeline()
        pipeline.startSession(consented: true, atTick: 0)
        pipeline.ingest(LensShadowMemoryFrame(tick: 0))
        pipeline.endTick(0)

        let snapshot = pipeline.inspectorSnapshot
        #expect(snapshot.ticksObserved == 1)
        #expect(snapshot.framesDropped == 1)

        let mirror = Mirror(reflecting: snapshot)
        for child in mirror.children {
            #expect(!(child.value is Data))
            #expect(!(child.value is [UInt8]))
        }
    }

    @Test("Draft copy strings exist for owner sign-off")
    func draftCopyExists() {
        #expect(!LensShadowCopy.draftCameraUsageDescription.isEmpty)
        #expect(!LensShadowCopy.draftTCCPreflight.isEmpty)
        #expect(!LensShadowCopy.draftShadowConsent.isEmpty)
    }
}
