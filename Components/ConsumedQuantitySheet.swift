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
    private var maxQuantity: Int { item.quantity }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Riduci la quantità in casa del numero che hai usato.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Controllo quantità: [ − ] numero [ + ]
                HStack(spacing: 24) {
                    Button {
                        if quantityToConsume > 1 { quantityToConsume -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(ThemeManager.shared.primaryColor)
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
                            .foregroundColor(ThemeManager.shared.primaryColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(quantityToConsume >= maxQuantity)
                    .opacity(quantityToConsume >= maxQuantity ? 0.4 : 1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                if maxQuantity > 1 {
                    Button {
                        quantityToConsume = maxQuantity
                    } label: {
                        Text("Tutti (\(maxQuantity))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ThemeManager.shared.primaryColor)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.fraction(0.38), .medium, .large])
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conferma") {
                        confirm()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeManager.shared.primaryColor)
                }
            }
            .onAppear {
                quantityToConsume = 1
            }
        }
    }
    
    private func confirm() {
        let amount = quantityToConsume
        if let onConfirm = onConfirm {
            onConfirm(amount)
        } else {
            applyConsumption(amount: amount)
        }
        dismiss()
    }
    
    private func applyConsumption(amount: Int) {
        let toRemove = min(amount, item.quantity)
        item.quantity -= toRemove
        if item.quantity <= 0 {
            item.quantity = 0
            item.isConsumed = true
            item.consumedDate = Date()
        }
        item.lastUpdated = Date()
        
        do {
            try modelContext.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("ConsumedQuantitySheet save error: \(error)")
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
