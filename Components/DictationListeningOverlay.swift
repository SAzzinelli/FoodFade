import SwiftUI

/// Vista a schermo intero per la dettatura: blur, waveform, solo "Sto ascoltando..." e pulsante X in cerchio grigio.
struct DictationListeningOverlay: View {
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)?
    @ObservedObject var dictationService: ExpirationDictationService = .shared
    
    private let barCount = 9
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .all)
            
            VStack(spacing: 32) {
                Spacer()
                
                VoiceWaveformView(level: dictationService.audioLevel, barCount: barCount)
                    .frame(height: 56)
                    .padding(.horizontal, 48)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 44))
                    .foregroundColor(ThemeManager.shared.primaryColor)
                
                Text("Sto ascoltando...")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    isPresented = false
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(.systemGray5)))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 50)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Barre verticali che reagiscono al livello audio (waveform).
private struct VoiceWaveformView: View {
    let level: Float
    let barCount: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(ThemeManager.shared.primaryColor)
                    .frame(width: 5, height: barHeight(for: i))
                    .animation(.easeOut(duration: 0.15), value: level)
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let center = barCount / 2
        let dist = abs(index - center)
        let base = CGFloat(level) * 40 + 8
        let wave = CGFloat(level) * 24 * (1 - CGFloat(dist) / CGFloat(center + 1))
        return max(6, base + wave)
    }
}

#Preview {
    DictationListeningOverlay(isPresented: .constant(true), onDismiss: {})
}
