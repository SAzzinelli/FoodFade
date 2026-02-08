import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import Combine

/// Componente per la selezione di foto (camera, libreria, file)
struct PhotoPickerView: View {
    @Binding var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingDocumentPicker = false
    
    @State private var showingFullScreen = false
    
    var body: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                // Anteprima più grande con card
                VStack(spacing: 12) {
                    Button {
                        showingFullScreen = true
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                // Indicatore zoom
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Image(systemName: "magnifyingglass.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.5))
                                            .clipShape(Circle())
                                            .padding(12)
                                    }
                                }
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    
                    // Pulsante elimina foto
                    Button {
                        selectedImage = nil
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Elimina foto")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .sheet(isPresented: $showingFullScreen) {
                    FullScreenImageView(image: image)
                }
            } else {
                Menu {
                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showingCamera = true
                        }
                    } label: {
                        Label("addfood.photo.take".localized, systemImage: "camera.fill")
                            .foregroundStyle(.primary)
                    }
                    
                    Button {
                        showingImagePicker = true
                    } label: {
                        Label("addfood.photo.library".localized, systemImage: "photo.on.rectangle")
                            .foregroundStyle(.primary)
                    }
                    
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("addfood.photo.file".localized, systemImage: "doc.fill")
                            .foregroundStyle(.primary)
                    }
                } label: {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                            Text("addfood.photo".localized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .tint(.primary)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(selectedImage: $selectedImage)
        }
    }
}

/// Wrapper per UIImagePickerController
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Document picker per selezionare immagini da file
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first,
                  let imageData = try? Data(contentsOf: url),
                  let image = UIImage(data: imageData) else {
                return
            }
            parent.selectedImage = image
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                } else if scale > 3.0 {
                                    withAnimation {
                                        scale = 3.0
                                        lastScale = 3.0
                                    }
                                }
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                                lastScale = 2.0
                            }
                        }
                    }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    PhotoPickerView(selectedImage: .constant(nil))
        .padding()
}

