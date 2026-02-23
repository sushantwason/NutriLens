import AVFoundation
import UIKit

@MainActor @Observable
final class CameraService: NSObject {
    let session = AVCaptureSession()
    var isAuthorized = false
    var capturedImage: UIImage?
    var scannedBarcode: String?
    var error: String?

    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var continuation: CheckedContinuation<UIImage?, Never>?
    private var barcodeContinuation: CheckedContinuation<String?, Never>?

    func checkAuthorization() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
    }

    func setupSession() {
        guard isAuthorized else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            error = "Camera not available"
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            error = "Cannot add photo output"
            session.commitConfiguration()
            return
        }

        session.addOutput(photoOutput)

        // Add metadata output for barcode scanning
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce]
        }

        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else { return }
        Task.detached(priority: .userInitiated) { [session] in
            session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        Task.detached(priority: .userInitiated) { [session] in
            session.stopRunning()
        }
    }

    func capturePhoto() async -> UIImage? {
        // Cancel any pending capture to prevent continuation leak
        continuation?.resume(returning: nil)
        continuation = nil

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func startBarcodeScanning() async -> String? {
        // Cancel any pending barcode scan to prevent continuation leak
        barcodeContinuation?.resume(returning: nil)
        barcodeContinuation = nil
        scannedBarcode = nil

        return await withCheckedContinuation { continuation in
            self.barcodeContinuation = continuation
        }
    }

    func stopBarcodeScanning() {
        barcodeContinuation?.resume(returning: nil)
        barcodeContinuation = nil
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            self.error = error.localizedDescription
            continuation?.resume(returning: nil)
            continuation = nil
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            self.error = "Failed to process captured photo"
            continuation?.resume(returning: nil)
            continuation = nil
            return
        }

        capturedImage = image
        continuation?.resume(returning: image)
        continuation = nil
    }
}

extension CameraService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let continuation = barcodeContinuation,
              let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        scannedBarcode = stringValue
        self.barcodeContinuation = nil
        continuation.resume(returning: stringValue)
    }
}
