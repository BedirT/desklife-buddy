import Foundation
import Testing
@testable import Epic5ContextSpikes

// NON-SHIPPING SPIKE — Epic 5 story S2 (issue #6).
// Boundary tests pinning what each public API does NOT return into the
// sanitized shapes. A failed spike ENDS its source; these tests guard the
// ceiling: if any probe ever retains a title, attendee, URL, window title,
// device identity, or history entry, the suite goes red and the source is
// dead by charter (no private API, no Control Center scraping, no process
// memory — ever).

private let t0 = Date(timeIntervalSince1970: 1_786_000_000)

@Suite("Context spike boundaries (non-shipping, S2)")
struct ContextSpikeBoundaryTests {
    // MARK: - Calendar (EventKit busy/free)

    @Test("calendar probe exposes no titles")
    func calendarProbeExposesNoTitles() {
        let raw = RawCalendarEvent(
            startDate: t0,
            endDate: t0.addingTimeInterval(1800),
            availability: .busy,
            title: "1:1 with Dana — performance review",
            location: "Room 4B",
            organizerName: "Dana",
            attendeeNames: ["Dana", "Lee"],
            url: URL(string: "https://meet.example.com/secret-room")!
        )
        let snapshot = CalendarBusyFreeProbe.sanitize(events: [raw], now: { t0 })
        #expect(snapshot.isBusy == true)
        #expect(snapshot.busyIntervalEnd == t0.addingTimeInterval(1800))
        let mirror = Mirror(reflecting: snapshot)
        #expect(!mirror.children.contains { $0.value is String })
        #expect(!String(reflecting: snapshot).contains("Dana"))
        #expect(!String(reflecting: snapshot).contains("secret-room"))
    }

    @Test("calendar probe retains no attendees, locations, or URLs")
    func calendarProbeRetainsNoAttendeesOrURLs() {
        let raw = RawCalendarEvent(
            startDate: t0,
            endDate: t0.addingTimeInterval(600),
            availability: .tentative,
            title: "Dentist",
            location: "500 Private St",
            organizerName: "Clinic",
            attendeeNames: ["Patient Zero"],
            url: URL(string: "https://clinic.example/x")!
        )
        let snapshot = CalendarBusyFreeProbe.sanitize(events: [raw], now: { t0 })
        let dumped = String(reflecting: snapshot)
        #expect(!dumped.contains("Patient Zero"))
        #expect(!dumped.contains("Private St"))
        #expect(!dumped.contains("clinic.example"))
        for child in Mirror(reflecting: snapshot).children {
            #expect(!(child.value is [String]))
            #expect(!(child.value is URL))
        }
    }

    @Test("calendar probe maps tentative/unavailable to busy, free to free")
    func calendarProbeAvailabilityMapping() {
        func busy(_ availability: RawAvailability) -> Bool {
            let raw = RawCalendarEvent(
                startDate: t0,
                endDate: t0.addingTimeInterval(300),
                availability: availability,
                title: "x", location: nil, organizerName: nil,
                attendeeNames: [], url: nil
            )
            return CalendarBusyFreeProbe.sanitize(events: [raw], now: { t0 }).isBusy
        }
        #expect(busy(.busy) == true)
        #expect(busy(.tentative) == true)
        #expect(busy(.unavailable) == true)
        #expect(busy(.free) == false)
        #expect(busy(.notSupported) == false)
    }

    @Test("calendar probe outside any interval is free with no end")
    func calendarProbeFreeWhenOutsideIntervals() {
        let raw = RawCalendarEvent(
            startDate: t0.addingTimeInterval(3600),
            endDate: t0.addingTimeInterval(5400),
            availability: .busy,
            title: "Later", location: nil, organizerName: nil,
            attendeeNames: [], url: nil
        )
        let snapshot = CalendarBusyFreeProbe.sanitize(events: [raw], now: { t0 })
        #expect(snapshot.isBusy == false)
        #expect(snapshot.busyIntervalEnd == nil)
    }

    // MARK: - Frontmost app (NSWorkspace, permission-free)

    @Test("frontmost-app probe retains no names, windows, or history")
    func frontmostProbeRetainsNoNamesOrHistory() {
        let probe = FrontmostAppProbe(selectedBundleIdentifier: "us.zoom.xos")
        let raw = RawFrontmostApp(
            bundleIdentifier: "us.zoom.xos",
            localizedName: "Zoom Meeting — Q3 Planning",
            processIdentifier: 4242,
            windowTitle: "Q3 Planning — confidential",
            launchDate: t0
        )
        let match = probe.sanitize(raw: raw)
        #expect(match.isSelectedActive == true)
        let dumped = String(reflecting: match)
        #expect(!dumped.contains("Zoom"))
        #expect(!dumped.contains("4242"))
        #expect(!dumped.contains("confidential"))
        for child in Mirror(reflecting: match).children {
            #expect(!(child.value is String))
            #expect(!(child.value is Int32))
        }
        // A second, non-matching sample leaves no trace of the first.
        let other = probe.sanitize(raw: RawFrontmostApp(
            bundleIdentifier: "com.apple.Safari",
            localizedName: "Safari",
            processIdentifier: 99,
            windowTitle: "Bank statement",
            launchDate: t0
        ))
        #expect(other.isSelectedActive == false)
        #expect(!String(reflecting: other).contains("Zoom"))
    }

    // MARK: - Media device busy (AVCaptureDevice, read-only boolean)

    @Test("media probe retains no device identity")
    func mediaProbeRetainsNoDeviceIdentity() {
        let raw = RawMediaDevice(
            isInUseByAnotherApplication: true,
            localizedName: "FaceTime HD Camera (Built-in)",
            uniqueID: "0x1440000005ac1ab",
            modelID: "Apple Camera VendorID_0x5ac_ProductID_0x8514",
            manufacturer: "Apple Inc."
        )
        let snapshot = MediaDeviceBusyProbe.sanitize(devices: [raw])
        #expect(snapshot.isBusy == true)
        let dumped = String(reflecting: snapshot)
        #expect(!dumped.contains("FaceTime"))
        #expect(!dumped.contains("0x1440"))
        #expect(!dumped.contains("Apple Inc."))
        #expect(!dumped.contains("VendorID"))
    }

    @Test("media probe is quiet when nothing is in use")
    func mediaProbeQuietWhenIdle() {
        let raw = RawMediaDevice(
            isInUseByAnotherApplication: false,
            localizedName: "Microphone",
            uniqueID: "uid-1", modelID: "m-1", manufacturer: "Vendor"
        )
        #expect(MediaDeviceBusyProbe.sanitize(devices: [raw]).isBusy == false)
        #expect(MediaDeviceBusyProbe.sanitize(devices: []).isBusy == false)
    }

    // MARK: - FaceTime (no independent public source on macOS)

    @Test("facetime has no independent source; derivative only")
    func facetimeProbeHasNoIndependentSource() {
        #expect(FaceTimeProbe.independentSource == nil)
        let assessment = FaceTimeProbe.assess(
            selectedAppActive: true,
            mediaDeviceBusy: true
        )
        #expect(assessment.likelyInCallContext == true)
        let dumped = String(reflecting: assessment)
        #expect(!dumped.contains("FaceTime"))
    }

    // MARK: - Structural ceiling: sanitized shapes carry no content types

    @Test("sanitized snapshots expose no strings, URLs, or collections")
    func sanitizedTypesExposeNoContent() {
        let snapshots: [Any] = [
            CalendarBusyFreeProbe.sanitize(events: [], now: { t0 }),
            FrontmostAppProbe(selectedBundleIdentifier: "x").sanitize(raw: nil),
            MediaDeviceBusyProbe.sanitize(devices: []),
            FaceTimeProbe.assess(selectedAppActive: false, mediaDeviceBusy: false),
        ]
        for snapshot in snapshots {
            for child in Mirror(reflecting: snapshot).children {
                #expect(!(child.value is String))
                #expect(!(child.value is URL))
                #expect(!(child.value is [String]))
                #expect(!(child.value is [URL]))
            }
        }
    }

    @Test("sanitizers are stateless and deterministic")
    func sanitizersAreStateless() {
        let raw = RawCalendarEvent(
            startDate: t0,
            endDate: t0.addingTimeInterval(300),
            availability: .busy,
            title: "Secret", location: nil, organizerName: nil,
            attendeeNames: ["A"], url: nil
        )
        let first = CalendarBusyFreeProbe.sanitize(events: [raw], now: { t0 })
        let second = CalendarBusyFreeProbe.sanitize(events: [raw], now: { t0 })
        #expect(first == second)
    }
}
