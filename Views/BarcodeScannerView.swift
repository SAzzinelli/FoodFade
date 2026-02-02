import SwiftUI
import AVFoundation
import Combine

/// Vista per la scansione di codici a barre
struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var scannerService: BarcodeScannerService
    let onBarcodeScanned: (String) -> Void
    
    @State private var cameraPermissionGranted = false
    @State private var scanAreaFrame: CGRect = .zero
    @State private var hasProcessedBarcode = false // Evita doppia elaborazione
    
    private let scanAreaSize: CGFloat = 250
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                if cameraPermissionGranted && scannerService.isScanning,
                   let session = scannerService.captureSession {
                    CameraPreviewView(session: session)
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
                    Color.black
                        .ignoresSafeArea()
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
                        Text("Posiziona il codice")
                            .foregroundColor(.white)
                            .font(.headline)
                        
                        Text("a barre qui")
                            .foregroundColor(.white.opacity(0.8))
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
                    
                    // Controlli - allineati in basso
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
                                    .foregroundColor(.white)
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
                                    .foregroundColor(.white)
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
                    Button("Chiudi") {
                        scannerService.stopScanning()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .task {
                print("🎬 BarcodeScannerView - task iniziato")
                // Richiedi permessi e avvia scanner in parallelo per velocità
                async let permission = scannerService.requestCameraPermission()
                cameraPermissionGranted = await permission
                print("📷 BarcodeScannerView - Permesso fotocamera: \(cameraPermissionGranted)")
                
                if cameraPermissionGranted {
                    print("🚀 BarcodeScannerView - Avvio scanning...")
                    // Avvia immediatamente senza delay
                    await scannerService.startScanning()
                    print("✅ BarcodeScannerView - Scanning avviato")
                } else {
                    print("❌ BarcodeScannerView - Permesso fotocamera negato")
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

