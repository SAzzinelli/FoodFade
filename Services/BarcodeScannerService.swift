import Foundation
@preconcurrency import AVFoundation
import UIKit
import Combine

/// Servizio per la scansione di codici a barre utilizzando AVFoundation
class BarcodeScannerService: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var scannedBarcode: String?
    @Published var errorMessage: String?
    
    var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var metadataOutput: AVCaptureMetadataOutput?
    
    /// Verifica i permessi della fotocamera
    @MainActor
    func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    /// Inizia la scansione
    @MainActor
    func startScanning() async {
        guard await requestCameraPermission() else {
            errorMessage = "Autorizzazione fotocamera negata"
            return
        }
        
        guard !isScanning else { return }
        
        let session = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            errorMessage = "Fotocamera non disponibile"
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            errorMessage = "Errore nella configurazione della fotocamera"
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            errorMessage = "Impossibile aggiungere input alla sessione"
            return
        }
        
        let output = AVCaptureMetadataOutput()
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .qr, .pdf417]
            
            // Salva il riferimento per configurare l'area di interesse
            self.metadataOutput = output
            
            // Configura l'area di interesse dopo che la sessione è pronta
            // L'area è normalizzata (0.0 - 1.0) con origine in alto a sinistra
            // Per ora lasciamo tutta l'area, sarà configurata meglio nella vista
        } else {
            errorMessage = "Impossibile aggiungere output alla sessione"
            return
        }
        
        captureSession = session
        isScanning = true
        errorMessage = nil
        
        // Avvia la sessione in background
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    /// Ferma la scansione e spegne la torcia se accesa
    @MainActor
    func stopScanning() {
        turnOffTorch()
        captureSession?.stopRunning()
        captureSession = nil
        videoPreviewLayer = nil
        metadataOutput = nil
        isScanning = false
        scannedBarcode = nil
    }
    
    /// Spegne la torcia (chiamato anche da stopScanning per evitare che resti accesa uscendo)
    @MainActor
    func turnOffTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch, device.torchMode == .on else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        } catch {
            print("Errore spegnimento torcia: \(error)")
        }
    }
    
    /// Attiva/disattiva la torcia
    @MainActor
    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
        } catch {
            print("Errore nel controllo della torcia: \(error)")
        }
    }
    
    /// Configura l'area di interesse per la scansione
    /// - Parameter rect: Rettangolo normalizzato (0.0-1.0) con origine in alto a sinistra
    @MainActor
    func configureScanArea(_ rect: CGRect) {
        guard let output = metadataOutput else {
            return
        }
        
        // L'area deve essere normalizzata e invertita verticalmente per AVFoundation
        // AVFoundation usa un sistema di coordinate con origine in basso a sinistra
        let normalizedRect = CGRect(
            x: rect.origin.x,
            y: 1.0 - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
        
        output.rectOfInterest = normalizedRect
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension BarcodeScannerService: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        print("🔍 BarcodeScannerService - metadataOutput chiamato con \(metadataObjects.count) oggetti")
        
        guard let metadataObject = metadataObjects.first else {
            print("⚠️ BarcodeScannerService - Nessun metadataObject trovato")
            return
        }
        
        guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else {
            print("⚠️ BarcodeScannerService - metadataObject non è AVMetadataMachineReadableCodeObject")
            return
        }
        
        guard let stringValue = readableObject.stringValue else {
            print("⚠️ BarcodeScannerService - stringValue è nil")
            return
        }
        
        print("✅ BarcodeScannerService - Barcode scansionato: \(stringValue)")
        
        Task { @MainActor in
            print("📱 BarcodeScannerService - Imposto scannedBarcode su MainActor: \(stringValue)")
            scannedBarcode = stringValue
            print("📱 BarcodeScannerService - scannedBarcode impostato, fermo scanning...")
            stopScanning()
            
            // Vibrazione di successo
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            print("✅ BarcodeScannerService - Vibrazione inviata")
        }
    }
}

