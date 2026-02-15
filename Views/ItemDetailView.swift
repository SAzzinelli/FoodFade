import SwiftUI
import SwiftData

/// Vista dettaglio di un singolo alimento - ARCHITETTURA FRIDGY DEFINITIVA
struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    let item: FoodItem
    @StateObject private var viewModel = ItemDetailViewModel()
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var showingConsumedQuantitySheet = false
    @State private var showingOpenedQuantitySheet = false
    @State private var showFridgyBravo = false
    @State private var showingError = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var showingExpiredOpenedAlert = false
    @State private var showingExpiredConsumedAlert = false
    @State private var pendingOpenedQuantity: Int? = nil
    
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
                                    .foregroundStyle(countdownNumberColor)
                                
                                Text(daysRemainingLabel)
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
                    .padding(.vertical, 4)
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
                        Label("itemdetail.scade_il".localized, systemImage: "calendar")
                            .font(.system(size: 15))
                            .foregroundStyle(detailAccentColor)
                        
                        Spacer()
                        
                        Text(item.effectiveExpirationDate.formatted(date: .long, time: .omitted))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(item.expirationStatus == .expired || item.expirationStatus == .today ? .red : detailAccentColor)
                    }
                    
                    // Data di aggiunta
                    HStack {
                        Label("itemdetail.added_on".localized, systemImage: "plus.circle.fill")
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
                            Label("itemdetail.last_update".localized, systemImage: "clock")
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text(item.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Dettagli aggiuntivi
                if item.isFresh || item.effectiveOpenedQuantity > 0 || item.useAdvancedExpiry || item.notes != nil || item.barcode != nil || item.price != nil {
                    Section {
                        if item.isFresh {
                            HStack {
                                Label("itemdetail.fresh_product".localized, systemImage: "leaf.fill")
                                    .font(.system(size: 15))
                                Spacer()
                                Text("itemdetail.opens_in_3".localized)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if item.effectiveOpenedQuantity > 0, let openedDate = item.openedDate {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("itemdetail.opened_product".localized, systemImage: "lock.open.fill")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.orange)
                                
                                HStack(spacing: 10) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                    Text("Aperto il \(openedDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 0)
                                }
                                
                                if item.quantity > item.effectiveOpenedQuantity && item.effectiveOpenedQuantity > 0 {
                                    let closedCount = item.quantity - item.effectiveOpenedQuantity
                                    let closedExp = item.unopenedExpirationDate
                                    let openedExp = Calendar.current.date(byAdding: .day, value: 3, to: openedDate) ?? openedDate
                                    
                                    HStack(spacing: 10) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.blue)
                                        Text(String(format: "itemdetail.portion.closed.count".localized, closedCount))
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.primary)
                                        Spacer(minLength: 0)
                                        Text(String(format: "itemdetail.portion.expires".localized, formatDateShort(closedExp)))
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 2)
                                    
                                    HStack(spacing: 10) {
                                        Image(systemName: "lock.open.fill")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.orange)
                                        Text(String(format: "itemdetail.portion.opened.count".localized, item.effectiveOpenedQuantity))
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.primary)
                                        Spacer(minLength: 0)
                                        Text(String(format: "itemdetail.portion.expires".localized, formatDateShort(openedExp)))
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    let openedExp = Calendar.current.date(byAdding: .day, value: 3, to: openedDate) ?? openedDate
                                    HStack(spacing: 10) {
                                        Image(systemName: "lock.open.fill")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.orange)
                                        Text(String(format: "itemdetail.portion.opened.count".localized, item.effectiveOpenedQuantity))
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.primary)
                                        Spacer(minLength: 0)
                                        Text(String(format: "itemdetail.portion.expires".localized, formatDateShort(openedExp)))
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 2)
                                }
                                Button {
                                    revertToUnopened()
                                } label: {
                                    Label("itemdetail.revert_to_unopened".localized, systemImage: "lock.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if item.useAdvancedExpiry && item.effectiveOpenedQuantity == 0 {
                            HStack {
                                Label("itemdetail.advanced_expiry".localized, systemImage: "clock.fill")
                                    .font(.system(size: 15))
                                Spacer()
                                Text("120 giorni se chiuso")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let notes = item.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("itemdetail.notes".localized, systemImage: "note.text")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.primary)
                                
                                Text(notes)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let barcode = item.barcode {
                            HStack {
                                Label("itemdetail.barcode".localized, systemImage: "barcode")
                                    .font(.system(size: 15))
                                Spacer()
                                Text(barcode)
                                    .font(.system(size: 15, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let price = item.price {
                            HStack {
                                Label("stats.costs.price_paid".localized, systemImage: "eurosign.circle")
                                    .font(.system(size: 15))
                                Spacer()
                                Text(price.formatted(.currency(code: "EUR")))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(12)
            .contentMargins(.top, 4, for: .scrollContent)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("itemdetail.title".localized)
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                            Button {
                                isEditing = true
                            } label: {
                                Label("itemdetail.edit".localized, systemImage: "pencil")
                                    .foregroundStyle(.primary)
                            }
                            Divider()
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("itemdetail.delete".localized, systemImage: "trash.fill")
                            }
                            .tint(.red)
                        } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.primary)
                    }
                    .tint(.primary)
                }
            }
            .presentationDragIndicator(.visible)
            .sheet(isPresented: $isEditing) {
                EditFoodView(item: item)
            }
            .sheet(isPresented: $showingConsumedQuantitySheet) {
                ConsumedQuantitySheet(item: item)
            }
            .sheet(isPresented: $showingOpenedQuantitySheet) {
                OpenedQuantitySheet(item: item) { count in
                    if item.expirationStatus == .expired {
                        pendingOpenedQuantity = count
                        showingOpenedQuantitySheet = false
                        showingExpiredOpenedAlert = true
                    } else {
                        applyOpened(quantity: count)
                        showingOpenedQuantitySheet = false
                    }
                }
            }
            .overlay {
                if showFridgyBravo {
                    FridgyBravoOverlay {
                        showFridgyBravo = false
                        dismiss()
                    }
                }
            }
            .onChange(of: showingConsumedQuantitySheet) { oldValue, newValue in
                if oldValue == true && newValue == false && item.isConsumed {
                    dismiss()
                }
            }
            .alert("Elimina Prodotto", isPresented: $showingDeleteConfirmation) {
                Button("common.annulla".localized, role: .cancel) {}
                Button("itemdetail.delete".localized, role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text(String(format: "itemdetail.delete_confirm".localized, item.name))
            }
            .alert(errorTitle, isPresented: $showingError) {
                Button("common.ok".localized, role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("itemdetail.expired_open_alert.title".localized, isPresented: $showingExpiredOpenedAlert) {
                Button("common.annulla".localized, role: .cancel) {
                    pendingOpenedQuantity = nil
                }
                Button("common.ok".localized) {
                    if let q = pendingOpenedQuantity {
                        applyOpened(quantity: q)
                        pendingOpenedQuantity = nil
                    } else {
                        if item.quantity == 1 {
                            applyOpened(quantity: 1)
                        } else {
                            showingOpenedQuantitySheet = true
                        }
                    }
                }
            } message: {
                Text("itemdetail.expired_open_alert.message".localized)
            }
            .alert("itemdetail.expired_consume_alert.title".localized, isPresented: $showingExpiredConsumedAlert) {
                Button("common.annulla".localized, role: .cancel) {}
                Button("itemdetail.expired_consume_alert.confirm".localized) {
                    markAsConsumed()
                }
            } message: {
                Text("itemdetail.expired_consume_alert.message".localized)
            }
            .task {
                await viewModel.loadFridgy(for: item)
            }
            .safeAreaInset(edge: .bottom) {
                actionButtons
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 8)
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
            // Pulsante L'hai aperto? (se scaduto → alert prima di procedere)
            if !item.isFresh {
                Button {
                    if item.expirationStatus == .expired {
                        showingExpiredOpenedAlert = true
                    } else if item.quantity == 1 {
                        applyOpened(quantity: 1)
                    } else {
                        showingOpenedQuantitySheet = true
                    }
                } label: {
                    Text("itemdetail.opened.button".localized)
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(ThemeManager.naturalHomeLogoColor).interactive(), in: .capsule)
            }
            
            // Pulsante Consumato (se scaduto → alert prima di procedere)
            Button {
                if item.quantity > 1 {
                    showingConsumedQuantitySheet = true
                } else if item.expirationStatus == .expired {
                    showingExpiredConsumedAlert = true
                } else {
                    markAsConsumed()
                }
            } label: {
                Text("itemdetail.consumed".localized)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(.green).interactive(), in: .capsule)
            .disabled(item.isConsumed)
        }
    }
    
    /// Riporta il prodotto allo stato "da aprire" (nessuna unità aperta).
    private func revertToUnopened() {
        item.openedQuantity = 0
        item.openedDate = nil
        item.isOpened = false
        item.lastUpdated = Date()
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            rescheduleNotificationsForCurrentItem()
        } catch {
            errorTitle = "error.save_failed".localized
            errorMessage = "error.save_failed_message".localized
            showingError = true
        }
    }
    
    private func applyOpened(quantity: Int) {
        let count = min(max(quantity, 1), item.quantity)
        item.openedQuantity = count
        item.openedDate = Date()
        item.isOpened = true
        item.lastUpdated = Date()
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            rescheduleNotificationsForCurrentItem()
        } catch {
            errorTitle = "error.save_failed".localized
            errorMessage = "error.save_failed_message".localized
            showingError = true
        }
    }
    
    /// Ri-programma le notifiche per questo item (usa effectiveExpirationDate: prima scadenza tra unità chiuse e aperte)
    private func rescheduleNotificationsForCurrentItem() {
        Task {
            let descriptor = FetchDescriptor<AppSettings>()
            guard let settings = try? modelContext.fetch(descriptor).first, settings.notificationsEnabled else { return }
            await NotificationService.shared.scheduleNotifications(for: item, daysBefore: settings.effectiveNotificationDays)
        }
    }
    
    private var categoryColor: Color {
        switch item.category {
        case .fridge: return .blue
        case .freezer: return .cyan
        case .pantry: return .orange
        }
    }
    
    /// Verde = OK, arancione = in scadenza o aperto, rosso = scaduto (numero, barra, pill)
    private var statusColor: Color {
        if item.expirationStatus == .expired { return .red }
        if item.effectiveOpenedQuantity > 0 { return .orange }
        if item.expirationStatus == .today || item.expirationStatus == .soon { return .orange }
        return .green
    }
    
    /// Stessa logica: verde OK, arancione in scadenza/aperto, rosso scaduto
    private var countdownNumberColor: Color {
        if item.daysRemaining < 0 { return .red }
        if item.effectiveOpenedQuantity > 0 { return .orange }
        if item.daysRemaining <= 2 { return .orange }
        return .green
    }
    
    private var detailAccentColor: Color {
        ThemeManager.shared.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor
    }
    
    private func formatDateShort(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
    
    /// Testo singolare/plurale: "1 giorno rimanente" / "X giorni rimanenti" o "1 giorno fa" / "X giorni fa"
    private var daysRemainingLabel: String {
        let n = abs(item.daysRemaining)
        if item.daysRemaining >= 0 {
            return n == 1 ? "giorno rimanente" : "giorni rimanenti"
        } else {
            return n == 1 ? "giorno fa" : "giorni fa"
        }
    }
    
    private func markAsConsumed() {
        item.isConsumed = true
        item.consumedDate = Date()
        item.lastUpdated = Date()
        
        do {
            try modelContext.save()
            showFridgyBravo = true
        } catch {
            errorTitle = "error.save_failed".localized
            errorMessage = "error.save_failed_message".localized
            showingError = true
        }
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorTitle = "error.delete_failed".localized
            errorMessage = "error.delete_failed_message".localized
            showingError = true
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

