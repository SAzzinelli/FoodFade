import SwiftUI
import AVFoundation
import UIKit

/// UIViewRepresentable per il preview della camera
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.setupPreviewLayer(session: session)
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updatePreviewLayer()
    }
}

/// UIView personalizzata per gestire correttamente il preview layer
class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    func setupPreviewLayer(session: AVCaptureSession) {
        if let layer = self.layer as? AVCaptureVideoPreviewLayer {
            layer.session = session
            layer.videoGravity = .resizeAspectFill
            previewLayer = layer
        }
    }
    
    func updatePreviewLayer() {
        if let layer = previewLayer {
            layer.frame = bounds
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePreviewLayer()
    }
}

