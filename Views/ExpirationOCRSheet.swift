import SwiftUI

/// Sheet beta: scatta o scegli una foto per estrarre solo la data di scadenza (OCR). Esclude tutto il resto.
struct ExpirationOCRSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onDateExtracted: (Date?) -> Void
    
    @State private var imageForOCR: UIImage?
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var isAnalyzing = false
    @State private var noDateAlert = false
    
    private let ocrColor = Color(red: 100/255, green: 175/255, blue: 230/255)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isAnalyzing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("addfood.ocr.analyzing".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("addfood.ocr.prompt".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 12) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                showingCamera = true
                            } label: {
                                Label("addfood.ocr.camera".localized, systemImage: "camera.fill")
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(ocrColor.opacity(0.15))
                                    .foregroundColor(ocrColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            showingLibrary = true
                        } label: {
                            Label("addfood.ocr.library".localized, systemImage: "photo.on.rectangle.angled")
                                .font(.system(size: 17, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color(.tertiarySystemFill))
                                .foregroundColor(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 32)
            .navigationTitle("addfood.ocr.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.annulla".localized) {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $imageForOCR)
            }
            .sheet(isPresented: $showingLibrary) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $imageForOCR)
            }
            .onChange(of: imageForOCR) { _, newImage in
                guard let img = newImage else { return }
                runOCR(image: img)
            }
            .alert("addfood.ocr.no_date.title".localized, isPresented: $noDateAlert) {
                Button("common.ok".localized) {
                    imageForOCR = nil
                }
            } message: {
                Text("addfood.ocr.no_date.message".localized)
            }
        }
    }
    
    private func runOCR(image: UIImage) {
        isAnalyzing = true
        Task {
            let date = await ExpirationOCRService.shared.extractExpirationDate(from: image)
            await MainActor.run {
                isAnalyzing = false
                if let date = date {
                    onDateExtracted(date)
                    dismiss()
                } else {
                    noDateAlert = true
                    imageForOCR = nil
                }
            }
        }
    }
}

#Preview {
    ExpirationOCRSheet { _ in }
}
