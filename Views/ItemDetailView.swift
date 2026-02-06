import SwiftUI
import SwiftData

/// Vista dettaglio di un singolo alimento - ARCHITETTURA FRIDGY DEFINITIVA
struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let item: FoodItem
    @StateObject private var viewModel = ItemDetailViewModel()
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    
    
    var body: some View {
        List {
                // Hero Section - Countdown principale
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        // Nome prodotto
                        Text(item.name)
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundStyle(.primary)
                        
                        // Luogo di conservazione e quantità
                        HStack {
                            Label(item.category.rawValue, systemImage: item.category.iconFill)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("Quantità: \(item.quantity)")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        
                        // Foto prodotto (se presente)
                        if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                            productPhotoView(image: uiImage)
                        }
                        
                        // Countdown principale
                        HStack(alignment: .bottom, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(abs(item.daysRemaining))")
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .foregroundStyle(item.daysRemaining <= 2 ? .orange : .green)
                                
                                Text(item.daysRemaining >= 0 ? "giorni rimanenti" : "giorni fa")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            // Badge stato
                            Text(item.expirationStatus.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(statusColor.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        
                        // Progress bar: si svuota man mano che diminuiscono i giorni alla scadenza (pieno = tanto tempo, vuoto = in scadenza)
                        ProgressView(value: item.expirationRemainingProgress)
                            .tint(statusColor)
                            .frame(height: 6)
                    }
                    .padding(.vertical, 8)
                }
                
                // Fridgy Card (se disponibile o in caricamento)
                if IntelligenceManager.shared.isFridgyAvailable {
                    Section {
                        if viewModel.isLoadingFridgy {
                            FridgySkeletonLoader()
                                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                                .listRowBackground(Color.clear)
                        } else if let message = viewModel.fridgyMessage,
                                  let context = viewModel.fridgyContext {
                            FridgyCard(context: context, message: message)
                                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                                .listRowBackground(Color.clear)
                                .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                
                // Informazioni principali
                Section {
                    // Data di scadenza
                    HStack {
                        Label("Scade il", systemImage: "calendar")
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(item.effectiveExpirationDate.formatted(date: .long, time: .omitted))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(item.expirationStatus == .expired || item.expirationStatus == .today ? .red : .primary)
                    }
                    
                    // Data di aggiunta
                    HStack {
                        Label("Aggiunto il", systemImage: "plus.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(item.createdAt.formatted(date: .long, time: .omitted))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Data ultimo aggiornamento (solo se diverso dalla data di creazione)
                    if item.lastUpdated != item.createdAt {
                        HStack {
                            Label("Ultimo aggiornamento", systemImage: "clock")
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text(item.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Timeline
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Timeline")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        TimelineBar(
                            currentDate: Date(),
                            createdAt: item.createdAt,
                            expirationDate: item.effectiveExpirationDate,
                            status: item.expirationStatus
                        )
                    }
                    .padding(.vertical, 4)
                }
                
                // Dettagli aggiuntivi
                if item.isFresh || item.isOpened || item.useAdvancedExpiry || item.notes != nil || item.barcode != nil {
                    Section {
                        if item.isFresh {
                            HStack {
                                Label("Prodotto fresco", systemImage: "leaf.fill")
                                    .font(.system(size: 15))
                                Spacer()
                                Text("Scade dopo 3 giorni")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if item.isOpened, let openedDate = item.openedDate {
                            HStack {
                                Label("Prodotto aperto", systemImage: "lock.open.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.orange)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Aperto il \(openedDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                    Text("Scade dopo 3 giorni")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        if item.useAdvancedExpiry && !item.isOpened {
                            HStack {
                                Label("Gestione avanzata", systemImage: "clock.fill")
                                    .font(.system(size: 15))
                                Spacer()
                                Text("120 giorni se chiuso")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let notes = item.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Note", systemImage: "note.text")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.primary)
                                
                                Text(notes)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let barcode = item.barcode {
                            HStack {
                                Label("Codice a barre", systemImage: "barcode")
                                    .font(.system(size: 15))
                                Spacer()
                                Text(barcode)
                                    .font(.system(size: 15, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dettaglio prodotto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            isEditing = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        Menu {
                            Button {
                                isEditing = true
                            } label: {
                                Label("Modifica", systemImage: "pencil")
                            }
                            Divider()
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Elimina", systemImage: "trash.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                EditFoodView(item: item)
            }
            .alert("Elimina Prodotto", isPresented: $showingDeleteConfirmation) {
                Button("Annulla", role: .cancel) {}
                Button("Elimina", role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text("Sei sicuro di voler eliminare \(item.name)?")
            }
            .task {
                await viewModel.loadFridgy(for: item)
            }
            .safeAreaInset(edge: .bottom) {
                actionButtons
                    .padding()
                    .background(.ultraThinMaterial)
            }
    }
    
    @State private var showingFullScreenPhoto = false
    
    private func productPhotoView(image: UIImage) -> some View {
        Button {
            showingFullScreenPhoto = true
        } label: {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    // Indicatore zoom
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .padding(12)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingFullScreenPhoto) {
            FullScreenImageView(image: image)
        }
    }
    
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Pulsante per cambiare stato aperto/chiuso (solo per prodotti non freschi)
            if !item.isFresh {
                Button {
                    toggleOpenedStatus()
                } label: {
                    Text("Aperto")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
            }
            
            // Pulsante Consumato - stile primario verde
            Button {
                markAsConsumed()
            } label: {
                Text("Consumato")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(item.isConsumed)
        }
    }
    
    private func toggleOpenedStatus() {
        item.isOpened.toggle()
        
        if item.isOpened {
            // Se viene aperto ora, imposta la data di apertura (scade dopo 3 giorni)
            item.openedDate = Date()
        } else {
            // Se viene chiuso, resetta la data di apertura (torna alla data originale)
            item.openedDate = nil
        }
        
        item.lastUpdated = Date()
        
        do {
            try modelContext.save()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Errore nel salvataggio: \(error)")
        }
    }
    
    private var categoryColor: Color {
        switch item.category {
        case .fridge: return .blue
        case .freezer: return .cyan
        case .pantry: return .orange
        }
    }
    
    private var statusColor: Color {
        switch item.expirationStatus {
        case .expired: return .red
        case .today: return .orange
        case .soon: return .yellow
        case .safe: return .green
        }
    }
    
    private func markAsConsumed() {
        item.isConsumed = true
        item.consumedDate = Date()
        item.lastUpdated = Date()
        
        do {
            try modelContext.save()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            dismiss()
        } catch {
            print("Errore nel salvataggio: \(error)")
        }
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Errore nell'eliminazione: \(error)")
        }
    }
}

private struct TimelineBar: View {
    let currentDate: Date
    let createdAt: Date
    let expirationDate: Date
    let status: ExpirationStatus
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Sfondo grigio (barra "piena")
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 6)
                
                // Parte colorata: si svuota man mano che si avvicina la scadenza (pieno = tanto tempo, vuoto = scaduto)
                RoundedRectangle(cornerRadius: 4)
                    .fill(progressColor)
                    .frame(width: progressWidth(in: geometry.size.width), height: 6)
            }
        }
        .frame(height: 6)
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: currentDate)
        let expiry = calendar.startOfDay(for: expirationDate)
        let created = calendar.startOfDay(for: createdAt)
        
        guard let daysRemaining = calendar.dateComponents([.day], from: now, to: expiry).day,
              let totalDays = calendar.dateComponents([.day], from: created, to: expiry).day,
              totalDays > 0 else {
            return 0
        }
        
        // Frazione tempo rimanente: 1 = pieno, 0 = vuoto (scaduto)
        let fraction = max(0, min(1, Double(daysRemaining) / Double(totalDays)))
        return totalWidth * CGFloat(fraction)
    }
    
    private var progressColor: Color {
        switch status {
        case .expired: return .red
        case .today: return .orange
        case .soon: return .yellow
        case .safe: return .green
        }
    }
}

#Preview {
    ItemDetailView(item: FoodItem(
        name: "Yogurt Greco",
        category: .fridge,
        expirationDate: Date().addingTimeInterval(86400 * 2)
    ))
    .modelContainer(for: FoodItem.self)
}

