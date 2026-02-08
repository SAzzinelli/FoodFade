import SwiftUI

/// Loader per il suggerimento Fridgy: overlay leggero con icona Fridgy (Bravo) e frase
/// Comunica che il caricamento non è istantaneo
struct FridgySkeletonLoader: View {
    @State private var opacity: Double = 0.6
    
    var body: some View {
        HStack(spacing: 14) {
            Image("FridgyBravo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
            
            Text("fridgy.loading".localized)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .opacity(opacity)
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                opacity = 1.0
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        FridgySkeletonLoader()
    }
    .padding()
}
