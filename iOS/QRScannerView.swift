import AVFoundation
import CompanionPhone
import SwiftUI

/// Camera QR scanner: AVFoundation metadata capture, no new dependencies.
///
/// Delivers each distinct code once through `onCode`; camera denial surfaces
/// through `onPermissionDenied` so the pane can show the localized recovery
/// copy instead of a dead viewfinder.
struct QRScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    var onPermissionDenied: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onPermissionDenied: onPermissionDenied)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        ScannerViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ controller: ScannerViewController, context: Context) {}

    final class Coordinator {
        let onCode: (String) -> Void
        let onPermissionDenied: () -> Void

        init(onCode: @escaping (String) -> Void, onPermissionDenied: @escaping () -> Void) {
            self.onCode = onCode
            self.onPermissionDenied = onPermissionDenied
        }
    }
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let coordinator: QRScannerView.Coordinator
    private var captureSession: AVCaptureSession?
    private var lastFiredCode: String?

    init(coordinator: QRScannerView.Coordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startCapture()
                    } else {
                        self?.coordinator.onPermissionDenied()
                    }
                }
            }
        case .denied, .restricted:
            coordinator.onPermissionDenied()
        @unknown default:
            coordinator.onPermissionDenied()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession?.stopRunning()
    }

    private func startCapture() {
        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            coordinator.onPermissionDenied()
            return
        }
        let session = AVCaptureSession()
        guard session.canAddInput(input) else {
            coordinator.onPermissionDenied()
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            coordinator.onPermissionDenied()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        preview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.layer.addSublayer(preview)
        captureSession = session
        session.startRunning()
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection,
    ) {
        guard
            let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue
        else { return }
        Task { @MainActor [weak self] in
            guard let self, code != self.lastFiredCode else { return }
            self.lastFiredCode = code
            self.coordinator.onCode(code)
        }
    }
}
