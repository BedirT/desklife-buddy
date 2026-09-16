import AppKit
import CoreImage
import DesignSystem
import SwiftUI

/// Renders one CoreImage QR bitmap from ceremony text. Local only: no
/// networking, no assets, no new dependencies.
enum CompanionQRCodeImage {
    static func make(from text: String, pixelsPerModule: CGFloat = 10) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: pixelsPerModule, y: pixelsPerModule))
        let white = CIImage(color: .white).cropped(to: scaled.extent)
        let composited = scaled.composited(over: white)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(composited, from: composited.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: composited.extent.width, height: composited.extent.height))
    }
}

/// The Mac pairing QR-sheet (Story A, issue #74): shows the live ceremony
/// `qrText` as a scannable code the phone scans. Body is layout only; every
/// transition lives in `CompanionPairingSheetModel`.
struct CompanionPairingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: CompanionPairingSheetModel

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text(CompanionPairingSheetL10n.sheetTitle)
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer(minLength: DSSpacing.md)
                Button(CompanionPairingSheetL10n.close) {
                    dismiss()
                }
                .accessibilityIdentifier("companion.pairing.close")
            }

            switch model.phase {
            case .loading:
                loadingBody
            case .showingCode:
                codeBody
            case .paired:
                pairedBody
            case .failed:
                failedBody
            case .unpaired:
                unpairedBody
            }
        }
        .font(textScale == .largest ? DSTypography.title : DSTypography.body)
        .padding(SettingsPageLayout.contentInset(for: textScale))
        .frame(width: 400)
        .background(Color.dsContentCanvas)
        .accessibilityIdentifier("companion.pairing.sheet")
        .task {
            model.prepare()
        }
    }

    private var loadingBody: some View {
        ProgressView(CompanionPairingSheetL10n.loadingMessage)
            .frame(maxWidth: .infinity, minHeight: 280)
            .accessibilityIdentifier("companion.pairing.loading")
    }

    private var codeBody: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(CompanionPairingSheetL10n.codeInstructions)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let qrText = model.qrText, let image = CompanionQRCodeImage.make(from: qrText) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(DSSpacing.md)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(CompanionPairingSheetL10n.qrCodeLabel)
                    .accessibilityIdentifier("companion.pairing.qrCode")
            } else {
                failedBody
            }
            Text(CompanionPairingSheetL10n.codeRegenerateNote)
                .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            DSButton(CompanionPairingSheetL10n.regenerate, style: .secondary) {
                model.regenerate()
            }
            .accessibilityIdentifier("companion.pairing.regenerate")
            DSButton(CompanionPairingSheetL10n.unpair, style: .destructive) {
                model.unpair()
            }
            .accessibilityIdentifier("companion.pairing.unpair")
        }
    }

    private var pairedBody: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Label(CompanionPairingSheetL10n.pairedTitle, systemImage: "checkmark.circle")
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
            Text(CompanionPairingSheetL10n.pairedMessage)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            DSButton(CompanionPairingSheetL10n.done, style: .primary) {
                dismiss()
            }
            .accessibilityIdentifier("companion.pairing.done")
            DSButton(CompanionPairingSheetL10n.unpair, style: .destructive) {
                model.unpair()
            }
            .accessibilityIdentifier("companion.pairing.unpair")
        }
    }

    private var failedBody: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Label(CompanionPairingSheetL10n.failedTitle, systemImage: "exclamationmark.triangle")
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
            Text(CompanionPairingSheetL10n.failedMessage)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            DSButton(CompanionPairingSheetL10n.retry, style: .primary) {
                model.retry()
            }
            .accessibilityIdentifier("companion.pairing.retry")
        }
        .accessibilityIdentifier("companion.pairing.error")
    }

    private var unpairedBody: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Label(CompanionPairingSheetL10n.unpairedTitle, systemImage: "iphone.slash")
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
            Text(CompanionPairingSheetL10n.unpairedMessage)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            DSButton(CompanionPairingSheetL10n.generateFresh, style: .primary) {
                model.prepare()
            }
            .accessibilityIdentifier("companion.pairing.generate")
        }
    }
}

#Preview("Pairing — Code") {
    CompanionPairingSheet(model: .preview(.showingCode))
        .frame(width: 440, height: 660)
        .background(Color.dsBackground)
}

#Preview("Pairing — Paired") {
    CompanionPairingSheet(model: .preview(.paired))
        .frame(width: 440, height: 480)
        .background(Color.dsBackground)
}

#Preview("Pairing — Loading") {
    CompanionPairingSheet(model: .preview(.loading))
        .frame(width: 440, height: 420)
        .background(Color.dsBackground)
}

#Preview("Pairing — Failed") {
    CompanionPairingSheet(model: .preview(.failed))
        .frame(width: 440, height: 420)
        .background(Color.dsBackground)
}

#Preview("Pairing — Unpaired") {
    CompanionPairingSheet(model: .preview(.unpaired))
        .frame(width: 440, height: 420)
        .background(Color.dsBackground)
}
