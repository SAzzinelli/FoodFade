import SwiftUI
import AVFoundation
import Combine

/// Vista per la scansione di codici a barre.
/// Su iOS 16+ usa DataScannerViewController (VisionKit) quando disponibile; altrimenti AVFoundation.
struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var scannerService: BarcodeScannerService
    let onBarcodeScanned: (String) -> Void

    @State private var cameraPermissionGranted = false
    @State private var scanAreaFrame: CGRect = .zero
    @State private var hasProcessedBarcode = false

    private let scanAreaSize: CGFloat = 250

    /// Sul simulatore la fotocamera non è disponibile (errori Fig -12710/-17281).
    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        #endif
    }

    /// VisionKit DataScanner disponibile (evita problemi AVFoundation su device reale).
    private static var useDataScanner: Bool {
        if #available(iOS 16.0, *) {
            return DataScannerRepresentable.isSupported() && DataScannerRepresentable.isAvailable()
        }
        return false
    }

    var body: some View {
        if Self.useDataScanner {
            dataScannerBody
        } else {
            avFoundationBody
        }
    }

    @available(iOS 16.0, *)
    private var dataScannerBody: some View {
        NavigationStack {
            ZStack {
                // Camera + DataScanner VisionKit
                DataScannerRepresentable(onBarcodeScanned: { code in
                    onBarcodeScanned(code)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dismiss() }
                }, onDismiss: { dismiss() })
                .ignoresSafeArea()

                // Overlay scuro con buco trasparente (come con AVFoundation)
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    RoundedRectangle(cornerRadius: 20)
                        .frame(width: scanAreaSize, height: scanAreaSize)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .allowsHitTesting(false)

                // Testo e controlli
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("barcode.placeholder".localized)
                            .foregroundColor(.white)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                    }
                    .offset(y: -scanAreaSize/2 - 40)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 60, height: 60)
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(ThemeManager.shared.primaryColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .frame(width: 60, height: 60)
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("Scansiona Codice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var avFoundationBody: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                if cameraPermissionGranted && scannerService.isScanning,
                   let session = scannerService.captureSession {
                    CameraPreviewView(session: session)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        configureScanArea(in: geometry)
                                    }
                                    .onChange(of: geometry.size) { _, _ in
                                        configureScanArea(in: geometry)
                                    }
                            }
                        )
                } else {
                    ZStack {
                        Color.black
                            .ignoresSafeArea()
                        if Self.isSimulator {
                            VStack(spacing: 16) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("barcode.simulator.title".localized)
                                    .foregroundColor(.white)
                                    .font(.headline)
                                Text("barcode.simulator.message".localized)
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        } else if !cameraPermissionGranted {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("barcode.camera.denied.title".localized)
                                    .foregroundColor(.white)
                                    .font(.headline)
                                Text("barcode.camera.denied.message".localized)
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        } else if !scannerService.isScanning, scannerService.errorMessage != nil {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.yellow)
                                Text(scannerService.errorMessage ?? "Errore fotocamera")
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                    }
                }
                
                // Overlay scuro con buco trasparente
                ZStack {
                    // Overlay scuro
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    // Buco trasparente per l'area di scansione
                    RoundedRectangle(cornerRadius: 20)
                        .frame(width: scanAreaSize, height: scanAreaSize)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                
                // Overlay UI
                VStack(spacing: 0) {
                    // Spacer superiore
                    Spacer()
                    
                    // Testo sopra l'area di scansione (senza bordo verde)
                    VStack(spacing: 4) {
                        Text("barcode.placeholder".localized)
                            .foregroundColor(.white)
                            .font(.headline)
                            .font(.subheadline)
                    }
                    .offset(y: -scanAreaSize/2 - 40)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    scanAreaFrame = geometry.frame(in: .global)
                                }
                        }
                    )
                    
                    // Spacer inferiore
                    Spacer()
                    
                    // Controlli - allineati in basso (colore icona come in AddFood per coerenza)
                    HStack(spacing: 40) {
                        // Torcia
                        Button {
                            scannerService.toggleTorch()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "bolt.fill")
                                    .font(.title2)
                                    .foregroundColor(ThemeManager.shared.primaryColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .frame(width: 60, height: 60)
                        
                        // Annulla
                        Button {
                            scannerService.stopScanning()
                            dismiss()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(ThemeManager.shared.primaryColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .frame(width: 60, height: 60)
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("Scansiona Codice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) {
                        scannerService.stopScanning()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .task {
                guard !Self.isSimulator else {
                    // Sul simulatore non avviare la camera (evita errori Fig -12710/-17281)
                    return
                }
                async let permission = scannerService.requestCameraPermission()
                cameraPermissionGranted = await permission
                if cameraPermissionGranted {
                    await scannerService.startScanning()
                }
            }
            .onDisappear {
                scannerService.stopScanning()
            }
            .onReceive(scannerService.$scannedBarcode) { barcode in
                print("🔄 BarcodeScannerView - onReceive scannedBarcode: \(barcode ?? "nil"), hasProcessedBarcode: \(hasProcessedBarcode)")
                
                guard let barcode = barcode, !hasProcessedBarcode else {
                    print("⚠️ BarcodeScannerView - Barcode nil o già processato")
                    return
                }
                
                hasProcessedBarcode = true
                print("✅ BarcodeScannerView - Barcode valido rilevato: \(barcode)")
                
                // Ferma la scansione immediatamente
                print("🛑 BarcodeScannerView - Fermo scanning...")
                scannerService.stopScanning()
                
                // Chiama il callback PRIMA di chiudere
                print("📞 BarcodeScannerView - Chiamo onBarcodeScanned")
                onBarcodeScanned(barcode)
                
                // Chiudi la vista dopo un breve delay per permettere al callback di completarsi
                print("🚪 BarcodeScannerView - Chiamo dismiss() tra 0.2 secondi...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    print("🚪 BarcodeScannerView - Eseguo dismiss()")
                    dismiss()
                    print("✅ BarcodeScannerView - dismiss() completato")
                }
            }
        }
    }
    
    private func configureScanArea(in geometry: GeometryProxy) {
        // L'area di scansione sarà configurata quando la sessione è pronta
        // Per ora lasciamo che scansiona tutta l'area
    }
}


#Preview {
    BarcodeScannerView(scannerService: BarcodeScannerService()) { barcode in
        print("Scanned: \(barcode)")
    }
}

