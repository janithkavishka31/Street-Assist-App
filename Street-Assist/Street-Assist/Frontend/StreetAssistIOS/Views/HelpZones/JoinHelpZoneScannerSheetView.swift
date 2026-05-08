import AVFoundation
import SwiftUI

struct JoinHelpZoneScannerSheetView: View {
    @Binding var isPresented: Bool
    var onManualEntry: () -> Void = {}
    var onScanned: (String) -> Void = { _ in }

    @State private var scannedCode: String = ""

    var body: some View {
        ZStack {
            AppTheme.sheetBackground
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Capsule()
                    .fill(AppTheme.border)
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)

                header

                scannerBox
                    .padding(.top, 6)

                Text("Point your camera at a Help-Zone QR\ncode to join instantly.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                Button {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onManualEntry()
                    }
                } label: {
                    Text("Enter Code Manually")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlue)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .onChange(of: scannedCode) { code in
            guard !code.isEmpty else { return }
            onScanned(code)
            isPresented = false
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Join a Help-Zone")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.subtleButtonBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    private var scannerBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.black.opacity(0.92))
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.04), Color.black.opacity(0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            QRCodeScannerView(scannedCode: $scannedCode)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .opacity(0.12)

            ScannerOverlay()
                .padding(44)

            Rectangle()
                .fill(AppTheme.primaryBlue)
                .frame(height: 3)
                .opacity(0.55)
                .padding(.horizontal, 64)
        }
        .frame(height: 320)
    }
}

private struct ScannerOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let size = min(w, h)

            ZStack {
                corner(x: 0, y: 0, rotation: 0)
                corner(x: size, y: 0, rotation: 90)
                corner(x: 0, y: size, rotation: -90)
                corner(x: size, y: size, rotation: 180)
            }
            .frame(width: size, height: size)
            .position(x: w / 2, y: h / 2)
        }
    }

    private func corner(x: CGFloat, y: CGFloat, rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .trim(from: 0, to: 0.25)
            .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            .frame(width: 80, height: 80)
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: y)
    }
}

private struct QRCodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .clear

        context.coordinator.configureSession(in: viewController)
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // no-op
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scannedCode: $scannedCode)
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let captureSession = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var didScan = false

        @Binding private var scannedCode: String

        init(scannedCode: Binding<String>) {
            _scannedCode = scannedCode
        }

        func configureSession(in viewController: UIViewController) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                startSession(in: viewController)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        guard let self, granted else { return }
                        self.startSession(in: viewController)
                    }
                }
            default:
                // Permission denied/restricted: keep placeholder UI.
                break
            }
        }

        private func startSession(in viewController: UIViewController) {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  captureSession.canAddInput(input)
            else {
                return
            }

            captureSession.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard captureSession.canAddOutput(output) else { return }
            captureSession.addOutput(output)

            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]

            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = viewController.view.bounds
            viewController.view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

            captureSession.startRunning()
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didScan else { return }
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue,
                  !value.isEmpty
            else {
                return
            }

            didScan = true
            scannedCode = value
            captureSession.stopRunning()
        }
    }
}

#Preview {
    JoinHelpZoneScannerSheetView(isPresented: .constant(true))
}
