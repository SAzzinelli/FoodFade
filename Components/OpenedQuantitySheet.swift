import SwiftUI
import SwiftData

/// Sheet per scegliere quante unità segnare come aperte (1...quantity).
struct OpenedQuantitySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let item: FoodItem
    var onConfirm: (Int) -> Void
    
    @State private var openedCount: Int = 1
    private var maxCount: Int { item.quantity }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("itemdetail.opened_quantity.prompt".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 24) {
                    Button {
                        if openedCount > 1 { openedCount -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(openedCount <= 1)
                    .opacity(openedCount <= 1 ? 0.4 : 1)
                    
                    Text("\(openedCount)")
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .frame(minWidth: 60)
                    
                    Button {
                        if openedCount < maxCount { openedCount += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(openedCount >= maxCount)
                    .opacity(openedCount >= maxCount ? 0.4 : 1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.tertiarySystemFill))
                .cornerRadius(16)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.fraction(0.35), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemBackground))
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.annulla".localized) {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("itemdetail.opened_quantity.confirm".localized) {
                        onConfirm(openedCount)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                }
            }
            .onAppear {
                openedCount = max(1, min(item.effectiveOpenedQuantity, item.quantity))
            }
        }
    }
}

#Preview {
    OpenedQuantitySheet(item: FoodItem(
        name: "Cracker",
        category: .pantry,
        expirationDate: Date().addingTimeInterval(86400 * 30),
        quantity: 4
    )) { _ in }
    .modelContainer(for: FoodItem.self, inMemory: true)
}
