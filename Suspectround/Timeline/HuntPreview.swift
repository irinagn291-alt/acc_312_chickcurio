import AVFoundation
import SwiftUI
import UIKit

/// Digit runs from a barcode or a QR payload. A 12-digit UPC-A gains a leading 0.
enum RetailCode {
    static func candidates(in payload: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\d{8,14}") else { return [] }
        let range = NSRange(payload.startIndex..., in: payload)
        var found: [String] = []
        for match in regex.matches(in: payload, range: range) {
            guard let slice = Range(match.range, in: payload) else { continue }
            var digits = String(payload[slice])
            if digits.count == 12 {
                digits = "0" + digits
            }
            if found.contains(digits) == false {
                found.append(digits)
            }
        }
        return found
    }
}

/// AVFoundation preview confined to naming and intake. The day board stays stock SwiftUI.
struct HuntPreview: UIViewRepresentable {
    var isRunning: Bool
    var onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PreviewHost {
        let host = PreviewHost()
        host.box.prepare(delegate: context.coordinator)
        return host
    }

    func updateUIView(_ uiView: PreviewHost, context: Context) {
        context.coordinator.onCode = onCode
        uiView.box.prepare(delegate: context.coordinator)
        if isRunning {
            uiView.box.start()
        } else {
            uiView.box.stop()
        }
    }

    static func dismantleUIView(_ uiView: PreviewHost, coordinator: Coordinator) {
        uiView.box.stop()
        coordinator.onCode = { _ in }
    }

    final class PreviewHost: UIView {
        let box = CaptureBox()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = UIColor(DesignTokens.surface)
            layer.addSublayer(box.preview)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.width > 1, bounds.height > 1 else { return }
            box.preview.frame = bounds
        }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: (String) -> Void = { _ in }
        private var lastDigits = ""
        private var lastFire = Date.distantPast

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            for object in metadataObjects {
                guard let code = object as? AVMetadataMachineReadableCodeObject,
                      let raw = code.stringValue,
                      let digits = RetailCode.candidates(in: raw).first else { continue }
                let now = Date()
                if digits == lastDigits, now.timeIntervalSince(lastFire) < 1.7 { return }
                lastDigits = digits
                lastFire = now
                onCode(digits)
                return
            }
        }
    }
}

/// Owns the capture session off the main thread. `stopRunning` runs on disappear and background.
final class CaptureBox: @unchecked Sendable {
    let session = AVCaptureSession()
    let preview = AVCaptureVideoPreviewLayer()
    private let output = AVCaptureMetadataOutput()
    private let queue = DispatchQueue(label: "spr.capture")
    private var configured = false

    init() {
        preview.videoGravity = .resizeAspectFill
        preview.session = session
    }

    func prepare(delegate: AVCaptureMetadataOutputObjectsDelegate) {
        queue.sync {
            guard configured == false else { return }
            session.beginConfiguration()
            session.sessionPreset = .high
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video)
            guard let device,
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input),
                  session.canAddOutput(output) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            session.addOutput(output)
            output.setMetadataObjectsDelegate(delegate, queue: .main)
            let wanted: [AVMetadataObject.ObjectType] = [
                .qr, .ean13, .ean8, .upce, .code128, .code39, .code93
            ]
            output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }
            if (try? device.lockForConfiguration()) != nil {
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            }
            session.commitConfiguration()
            configured = true
        }
    }

    func start() {
        queue.async { [self] in
            guard configured, session.isRunning == false else { return }
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }
}

/// Permission gate in front of the preview. Continue is the only step before the system prompt.
struct HuntCapture: View {
    var onCode: (String) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var status = AVCaptureDevice.authorizationStatus(for: .video)

    /// Live ReviewScreen launches must not start AVCapture — a zero-size preview
    /// layer during landscape sheet layout drops the app behind SpringBoard.
    private var reviewShot: Bool {
        ProcessInfo.processInfo.arguments.contains(ReviewLaunch.argument)
    }

    private var hasCamera: Bool {
        reviewShot == false && AVCaptureDevice.default(for: .video) != nil
    }

    private var running: Bool {
        hasCamera && status == .authorized && scenePhase == .active
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            previewBlock
            if reviewShot || hasCamera == false {
                Text("Camera is unavailable. Type a name or use a chip.")
                    .font(TypeScale.font(.body))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else if status == .notDetermined {
                Text("Scan a code to name the food.")
                    .font(TypeScale.font(.body))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Continue") {
                    AVCaptureDevice.requestAccess(for: .video) { _ in
                        Task { @MainActor in
                            status = AVCaptureDevice.authorizationStatus(for: .video)
                        }
                    }
                }
                .buttonStyle(SoftCardButtonStyle(kind: .accent))
            } else if status == .denied || status == .restricted {
                Text(status == .restricted
                    ? "Camera is restricted. Open Settings to scan a code."
                    : "Camera is denied. Open Settings to scan a code.")
                    .font(TypeScale.font(.body))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(SoftCardButtonStyle(kind: .quiet))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                status = AVCaptureDevice.authorizationStatus(for: .video)
            } else {
                ReviewLaunch.bringForward()
            }
        }
    }

    @ViewBuilder
    private var previewBlock: some View {
        Group {
            if reviewShot || hasCamera == false {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(DesignTokens.surface)
                    .overlay {
                        Image(systemName: "barcode.viewfinder")
                            .font(TypeScale.font(.display))
                            .foregroundStyle(DesignTokens.muted)
                    }
                    .accessibilityLabel("Barcode camera")
            } else {
                HuntPreview(isRunning: running, onCode: onCode)
                    .accessibilityLabel("Barcode camera")
            }
        }
        // Fixed aspect — not containerRelativeFrame. In a landscape sheet the
        // vertical container can resolve to 0 and a zero-size preview layer
        // drops the app behind SpringBoard.
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(minHeight: Spacing.s48)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
