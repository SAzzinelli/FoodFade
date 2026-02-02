import SwiftUI
import SwiftData
import Foundation
import UniformTypeIdentifiers

/// Vista per backup e ripristino dati
struct BackupRestoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private let backupService = BackupService.shared
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showingImportPicker = false
    @State private var showingImportMode = false
    @State private var importMode: ImportMode = .merge
    @State private var showingImportResult = false
    @State private var importResult: ImportResult?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    
    @Query private var allItems: [FoodItem]
    @Query private var settings: [AppSettings]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Backup Manuale")
                            .font(.system(size: 17, weight: .semibold))
                        
                        Text("Esporta tutti i tuoi dati in un file JSON. Puoi salvare questo file per un backup locale o condividerlo.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("\(allItems.count) prodotti, \(settings.count) impostazioni")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Button {
                        exportData()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Esporta Dati")
                        }
                    }
                    .disabled(isExporting || isImporting)
                    
                    if isExporting {
                        HStack {
                            ProgressView()
                            Text("Esportazione in corso...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Esporta")
                } footer: {
                    if settings.first?.iCloudSyncEnabled == true {
                        Text("Con iCloud attivo, i dati si sincronizzano automaticamente. Questo backup è utile per un backup locale aggiuntivo.")
                    } else {
                        Text("Esporta tutti i tuoi dati in un file JSON per un backup locale.")
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ripristina Dati")
                            .font(.system(size: 17, weight: .semibold))
                        
                        Text("Importa dati da un file di backup. Puoi scegliere di sostituire tutti i dati o unirli a quelli esistenti.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Button {
                        showingImportPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Importa Dati")
                        }
                    }
                    .disabled(isExporting || isImporting)
                    
                    if isImporting {
                        HStack {
                            ProgressView()
                            Text("Importazione in corso...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Importa")
                } footer: {
                    if settings.first?.iCloudSyncEnabled == true {
                        Text("⚠️ Con iCloud attivo, i dati importati verranno sincronizzati automaticamente. Assicurati di non creare duplicati.")
                    }
                }
            }
            .navigationTitle("Backup e Ripristino")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        importData(from: url)
                    }
                case .failure(let error):
                    errorMessage = "Errore nella selezione del file: \(error.localizedDescription)"
                    showingError = true
                }
            }
            .confirmationDialog("Modalità Importazione", isPresented: $showingImportMode) {
                Button("Unisci (Consigliato)") {
                    importMode = .merge
                    performImport()
                }
                Button("Sostituisci Tutto", role: .destructive) {
                    importMode = .replace
                    performImport()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Come vuoi importare i dati?\n\n• Unisci: aggiunge solo prodotti nuovi\n• Sostituisci: elimina tutto e importa dal backup")
            }
            .alert("Risultato Importazione", isPresented: $showingImportResult) {
                Button("OK", role: .cancel) {}
            } message: {
                if let result = importResult {
                    Text("Importati: \(result.imported)\nAggiornati: \(result.updated)\nSaltati: \(result.skipped)\n\nTotale nel backup: \(result.totalInBackup)")
                }
            }
            .alert("Errore", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                settingsViewModel.setup(modelContext: modelContext)
            }
        }
    }
    
    private func exportData() {
        isExporting = true
        
        Task {
            do {
                let data = try backupService.exportData(modelContext: modelContext)
                
                // Salva in un file temporaneo
                let fileName = "FoodFade_Backup_\(Date().formatted(date: .numeric, time: .omitted)).json"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: tempURL)
                
                await MainActor.run {
                    exportURL = tempURL
                    isExporting = false
                    showingShareSheet = true
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Errore nell'esportazione: \(error.localizedDescription)"
                    showingError = true
                    isExporting = false
                }
            }
        }
    }
    
    @State private var importURL: URL?
    
    private func importData(from url: URL) {
        importURL = url
        showingImportMode = true
    }
    
    private func performImport() {
        guard let url = importURL else { return }
        
        isImporting = true
        
        Task {
            do {
                // Accedi al file
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                
                let data = try Data(contentsOf: url)
                let result = try backupService.importData(
                    from: data,
                    modelContext: modelContext,
                    mergeMode: importMode
                )
                
                await MainActor.run {
                    importResult = result
                    showingImportResult = true
                    isImporting = false
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Errore nell'importazione: \(error.localizedDescription)"
                    showingError = true
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

