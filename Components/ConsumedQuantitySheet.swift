import SwiftUI
import SwiftData

/// Sheet per scegliere quanti pezzi segnare come consumati (controlli +/−).
/// Non a schermo intero; usare con presentationDetents.
struct ConsumedQuantitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let item: FoodItem
    var onConfirm: ((Int) -> Void)?
    
    @State private var quantityToConsume: Int = 1
    @State private var showingSaveError = false
    @State private var showFridgyBravo = false
    private var maxQuantity: Int { item.quantity }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("consumed_quantity_sheet.prompt".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                
                // Controllo quantità: [ − ] numero [ + ] — centrato, meno grigio, più nero
                HStack(spacing: 24) {
                    Button {
                        if quantityToConsume > 1 { quantityToConsume -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(quantityToConsume <= 1)
                    .opacity(quantityToConsume <= 1 ? 0.4 : 1)
                    
                    Text("\(quantityToConsume)")
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .frame(minWidth: 60)
                    
                    Button {
                        if quantityToConsume < maxQuantity { quantityToConsume += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(quantityToConsume >= maxQuantity)
                    .opacity(quantityToConsume >= maxQuantity ? 0.4 : 1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.tertiarySystemFill))
                .cornerRadius(16)
                
                if maxQuantity > 1 {
                    Button {
                        quantityToConsume = maxQuantity
                    } label: {
                        Text(String(format: "consumed_quantity_sheet.all".localized, maxQuantity))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(12)
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.fraction(0.38), .medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemBackground))
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conferma") {
                        confirm()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                }
            }
            .onAppear {
                quantityToConsume = 1
            }
            .overlay {
                if showFridgyBravo {
                    FridgyBravoOverlay {
                        showFridgyBravo = false
                        dismiss()
                    }
                }
            }
            .alert("error.save_failed".localized, isPresented: $showingSaveError) {
                Button("common.ok".localized, role: .cancel) {}
            } message: {
                Text("error.save_failed_message".localized)
            }
        }
    }
    
    private func confirm() {
        let amount = quantityToConsume
        if let onConfirm = onConfirm {
            onConfirm(amount)
            dismiss()
        } else {
            applyConsumption(amount: amount)
            showFridgyBravo = true
        }
    }
    
    private func applyConsumption(amount: Int) {
        let toRemove = min(amount, item.quantity)
        item.quantity -= toRemove
        item.openedQuantity = max(0, item.openedQuantity - toRemove)
        if item.quantity <= 0 {
            item.quantity = 0
            item.isConsumed = true
            item.consumedDate = Date()
        }
        item.lastUpdated = Date()
        
        do {
            try modelContext.save()
            rescheduleOrCancelNotifications()
        } catch {
            showingSaveError = true
        }
    }
    
    /// Se consumato: cancella notifiche. Altrimenti ri-programma in base a effectiveExpirationDate (unità rimanenti).
    private func rescheduleOrCancelNotifications() {
        Task {
            if item.isConsumed {
                await NotificationService.shared.cancelNotifications(for: item.id)
            } else {
                let descriptor = FetchDescriptor<AppSettings>()
                guard let settings = try? modelContext.fetch(descriptor).first, settings.notificationsEnabled else { return }
                await NotificationService.shared.scheduleNotifications(for: item, daysBefore: settings.effectiveNotificationDays)
            }
        }
    }
}

#Preview {
    ConsumedQuantitySheet(item: FoodItem(
        name: "Yogurt",
        category: .fridge,
        expirationDate: Date(),
        quantity: 6
    ))
    .modelContainer(for: FoodItem.self, inMemory: true)
}
