import SwiftUI

/// Skeleton loader per Fridgy Card
/// Mostrato mentre Fridgy sta generando il suggerimento
struct FridgySkeletonLoader: View {
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icona skeleton
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 36, height: 36)
            
            // Contenuto skeleton
            VStack(alignment: .leading, spacing: 6) {
                // Titolo skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 12)
                
                // Messaggio skeleton (2 righe)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 200, height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 160, height: 12)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.gray.opacity(0.1))
        )
        .overlay(
            // Shimmer effect
            GeometryReader { geometry in
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width)
                .offset(x: shimmerOffset)
            }
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 400
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
