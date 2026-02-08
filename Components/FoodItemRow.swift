import SwiftUI
import SwiftData

/// Riga nella lista per un FoodItem - Design pulito e organizzato
struct FoodItemRow: View {
    let item: FoodItem
    let onConsume: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var daysText: String {
        item.daysRemaining == 1 ? "item.day".localized : String(format: "item.days".localized, item.daysRemaining)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icona categoria (dimensione fissa)
            Image(systemName: item.category.iconFill)
                .font(.system(size: 20))
                .foregroundColor(categoryColor)
                .frame(width: 40, height: 40)
                .background(categoryColor.opacity(0.1))
                .cornerRadius(10)
            
            // Nome + metadati in colonna, con spazio garantito
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                // Giorni e quantità su una sola riga orizzontale (evita glitch verticali)
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(daysText)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text("·")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Qtà. \(item.quantity)")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            
            // Badge stato (dimensione fissa, non comprime il centro)
            Text(item.expirationStatus.rawValue)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor)
                .cornerRadius(8)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .contextMenu {
            Button(action: onConsume) {
                Label("inventory.mark.consumed".localized, systemImage: "checkmark.circle")
                    .foregroundStyle(.primary)
            }
            
            Button(action: onEdit) {
                Label("common.edit".localized, systemImage: "pencil")
                    .foregroundStyle(.primary)
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("common.delete".localized, systemImage: "trash")
            }
            .tint(.red)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.daysRemaining == 1 ? "item.day".localized : String(format: "item.days".localized, item.daysRemaining)), \(item.expirationStatus.rawValue)")
        .accessibilityHint("item.accessibility.hint".localized)
    }
    
    private var categoryColor: Color {
        AppTheme.color(for: item.category)
    }
    
    private var statusColor: Color {
        switch item.expirationStatus {
        case .expired: return .red
        case .today: return .orange
        case .soon: return .orange
        case .safe: return .green
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FoodItem.self, configurations: config)
    let context = ModelContext(container)
    let item = FoodItem(
        name: "Yogurt Greco",
        category: .fridge,
        expirationDate: Date().addingTimeInterval(86400 * 2)
    )
    context.insert(item)
    try? context.save()
    return List {
        FoodItemRow(item: item, onConsume: {}, onEdit: {}, onDelete: {})
    }
    .listStyle(.insetGrouped)
    .modelContainer(container)
}
