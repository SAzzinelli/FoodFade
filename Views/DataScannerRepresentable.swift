import SwiftUI
import Vision
import VisionKit

/// Wrapper SwiftUI per DataScannerViewController (VisionKit).
/// Usa l'API di sistema per la camera e la scansione barcode, evitando i problemi di AVFoundation su alcuni device.
@available(iOS 16.0, *)
struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onBarcodeScanned: (String) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let types: Set<DataScannerViewController.RecognizedDataType> = [
            .barcode(symbologies: [.qr, .ean8, .ean13, .upce, .code128, .pdf417])
        ]
        let vc = DataScannerViewController(
            recognizedDataTypes: types,
            isGuidanceEnabled: false, // Evita il messaggio "muovi lentamente" di sistema
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeScanned: onBarcodeScanned, onDismiss: onDismiss)
    }

    static func isSupported() -> Bool {
        DataScannerViewController.isSupported
    }

    static func isAvailable() -> Bool {
        DataScannerViewController.isAvailable
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcodeScanned: (String) -> Void
        let onDismiss: () -> Void
        private var hasProcessed = false

        init(onBarcodeScanned: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
            self.onBarcodeScanned = onBarcodeScanned
            self.onDismiss = onDismiss
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            processItem(item)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard let first = addedItems.first else { return }
            processItem(first)
        }

        private func processItem(_ item: RecognizedItem) {
            guard !hasProcessed else { return }
            guard case .barcode(let barcode) = item else { return }
            let payload = barcode.payloadStringValue ?? ""
            guard !payload.isEmpty else { return }
            hasProcessed = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onBarcodeScanned(payload)
            onDismiss()
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {}
        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {}
    }
}
