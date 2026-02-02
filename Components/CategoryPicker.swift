import SwiftUI

/// Selettore di categoria con icone SF Symbols
struct CategoryPicker: View {
    @Binding var selectedCategory: FoodCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categoria")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }
}

private struct CategoryButton: View {
    let category: FoodCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : categoryColor)
                    .frame(width: 50, height: 50)
                    .background(isSelected ? categoryColor : categoryColor.opacity(0.1))
                    .cornerRadius(12)
                
                Text(category.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? categoryColor : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? categoryColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var categoryColor: Color {
        switch category {
        case .fridge: return .blue
        case .freezer: return .cyan
        case .pantry: return .orange
        }
    }
}

#Preview {
    CategoryPicker(selectedCategory: .constant(.fridge))
        .padding()
}

