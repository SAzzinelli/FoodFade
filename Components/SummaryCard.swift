import SwiftUI

/// Card di riepilogo per la dashboard
struct SummaryCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var animatedCount: Int = 0
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    Spacer()
                }
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(animatedCount)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedCount = count
            }
        }
        .onChange(of: count) { oldValue, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedCount = newValue
            }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        SummaryCard(
            title: "Scadono Oggi",
            count: 3,
            icon: "exclamationmark.triangle.fill",
            color: .orange
        ) {}
        
        SummaryCard(
            title: "Prossimi",
            count: 5,
            icon: "clock.fill",
            color: .yellow
        ) {}
    }
    .padding()
}

