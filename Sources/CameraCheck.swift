import AppKit
import AVFoundation
import SwiftUI

/// The camera behind the alert's 🪞 button. The session only runs while the mirror is open.
final class CameraCheck {
    enum State { case off, starting, live, denied, noCamera }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "notchfall.camera")
    private var configured = false
    var onState: (State) -> Void = { _ in }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: run()
        case .notDetermined:
            onState(.starting)
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { ok ? self.run() : self.onState(.denied) }
            }
        default: onState(.denied)
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    private func run() {
        onState(.starting)
        queue.async { [self] in
            if !configured {
                guard let cam = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: cam), session.canAddInput(input) else {
                    return DispatchQueue.main.async { self.onState(.noCamera) }
                }
                session.beginConfiguration()
                session.sessionPreset = .high
                session.addInput(input)
                session.commitConfiguration()
                configured = true
            }
            session.startRunning()
            DispatchQueue.main.async { self.onState(self.session.isRunning ? .live : .noCamera) }
        }
    }
}

/// Live, mirrored camera preview (like Photo Booth), so you see yourself the way others will.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let c = layer.connection, c.isVideoMirroringSupported {
            c.automaticallyAdjustsVideoMirroring = false
            c.isVideoMirrored = true
        }
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        v.layer = layer
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Stand-in picture for the docs and screenshots, so the README never shows a real camera.
struct FakeCameraScene: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(colors: [rgb(0.32, 0.36, 0.5), rgb(0.62, 0.52, 0.48)], startPoint: .topLeading, endPoint: .bottomTrailing)
                // A window of soft light behind the "person".
                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.18)).frame(width: 120, height: 150).offset(x: 150, y: -30).blur(radius: 6)
                Circle().fill(rgb(1, 0.8, 0.5).opacity(0.35)).frame(width: 60).offset(x: -170, y: -55).blur(radius: 18)
                VStack(spacing: -10) {
                    ZStack(alignment: .top) {
                        Ellipse().fill(LinearGradient(colors: [rgb(0.95, 0.8, 0.68), rgb(0.82, 0.64, 0.52)],
                                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 70, height: 82)
                        // Hair
                        Ellipse().fill(rgb(0.22, 0.16, 0.13)).frame(width: 76, height: 40).offset(y: -6)
                    }
                    .zIndex(1)
                    Rectangle().fill(rgb(0.84, 0.66, 0.54)).frame(width: 26, height: 20)
                    UnevenRoundedRectangle(topLeadingRadius: 70, topTrailingRadius: 70)
                        .fill(LinearGradient(colors: [rgb(0.25, 0.48, 0.85), rgb(0.16, 0.33, 0.66)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 210, height: 110)
                }
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                .offset(x: sin(t * 0.8) * 3, y: 52 + cos(t * 0.6) * 2)
            }
        }
    }
}
