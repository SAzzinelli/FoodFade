import SwiftUI

/// Card "Oggi per te": frase suggerita + sottotitolo opzionale + barra distribuzione (se si passano i conteggi).
struct ExpiryControlCardView: View {
    let suggestion: OggiPerTeSuggestion
    var subtitle: String? = nil
    var scadonoOggi: Int = 0
    var daConsumare: Int = 0
    var neiProssimiGiorni: Int = 0
    var tuttoOk: Int = 0
    var totaleProdottiAttivi: Int = 0

    @State private var appeared = false

    private var suggestionText: String {
        switch suggestion {
        case .consumeTodayOne(let name):
            return String(format: "home.oggi_per_te.consume_today_one".localized, name)
        case .consumeTodayMany(let count):
            return String(format: "home.oggi_per_te.consume_today_many".localized, count)
        case .consumeTomorrowOne(let name):
            return String(format: "home.oggi_per_te.consume_tomorrow_one".localized, name)
        case .consumeInDaysOne(let name, let days):
            return String(format: "home.oggi_per_te.consume_in_days_one".localized, name, days)
        case .consumeTomorrowMany(let count):
            return String(format: "home.oggi_per_te.consume_tomorrow_many".localized, count)
        case .incomingSoon:
            return "home.oggi_per_te.incoming_soon".localized
        case .fridgeUnderControl:
            return fridgeOkVariant
        case .noUrgency:
            return "home.oggi_per_te.no_urgency".localized
        }
    }

    private var fridgeOkVariant: String {
        let day = Calendar.current.component(.weekday, from: Date())
        switch day % 3 {
        case 1: return "home.oggi_per_te.fridge_ok".localized
        case 2: return "home.oggi_per_te.fridge_ok_alt1".localized
        default: return "home.oggi_per_te.fridge_ok_alt2".localized
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)
                .padding(.top, 4)
                .padding(.trailing, 14)

            VStack(alignment: .leading, spacing: 12) {
                Text("home.oggi_per_te.title".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(suggestionText)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }

                if totaleProdottiAttivi > 0 {
                    OggiPerTeSegmentedBar(
                        scadonoOggi: scadonoOggi,
                        daConsumare: daConsumare,
                        neiProssimiGiorni: neiProssimiGiorni,
                        tuttoOk: tuttoOk,
                        total: totaleProdottiAttivi
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.vertical, 18)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                appeared = true
            }
        }
    }

    private var accentColor: Color {
        switch suggestion {
        case .consumeTodayOne, .consumeTodayMany:
            return Color(red: 0.88, green: 0.32, blue: 0.32)
        case .consumeTomorrowOne, .consumeInDaysOne, .consumeTomorrowMany:
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .incomingSoon:
            return Color(red: 0.95, green: 0.75, blue: 0.2)
        case .fridgeUnderControl, .noUrgency:
            return Color(red: 0.22, green: 0.58, blue: 0.48)
        }
    }
}

// MARK: - Barra distribuzione (rosso / arancione / giallo / verde)
private struct OggiPerTeSegmentedBar: View {
    let scadonoOggi: Int
    let daConsumare: Int
    let neiProssimiGiorni: Int
    let tuttoOk: Int
    let total: Int

    private let height: CGFloat = 8
    private let cornerRadius: CGFloat = 4

    private static let red = Color(red: 0.88, green: 0.32, blue: 0.32)
    private static let orange = Color(red: 1.0, green: 0.6, blue: 0.2)
    private static let yellow = Color(red: 0.95, green: 0.75, blue: 0.2)
    private static let green = Color(red: 0.22, green: 0.58, blue: 0.48)

    @State private var a: CGFloat = 0
    @State private var b: CGFloat = 0
    @State private var c: CGFloat = 0
    @State private var d: CGFloat = 0

    private var totalF: CGFloat { CGFloat(max(1, total)) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: height)
                HStack(spacing: 0) {
                    if scadonoOggi > 0 {
                        Rectangle()
                            .fill(Self.red)
                            .frame(width: max(0, w * (a / totalF)), height: height)
                    }
                    if daConsumare > 0 {
                        Rectangle()
                            .fill(Self.orange)
                            .frame(width: max(0, w * (b / totalF)), height: height)
                    }
                    if neiProssimiGiorni > 0 {
                        Rectangle()
                            .fill(Self.yellow)
                            .frame(width: max(0, w * (c / totalF)), height: height)
                    }
                    if tuttoOk > 0 {
                        Rectangle()
                            .fill(Self.green)
                            .frame(width: max(0, w * (d / totalF)), height: height)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        .frame(height: height)
        .onAppear { animate() }
        .onChange(of: scadonoOggi) { _, _ in animate() }
        .onChange(of: daConsumare) { _, _ in animate() }
        .onChange(of: neiProssimiGiorni) { _, _ in animate() }
        .onChange(of: tuttoOk) { _, _ in animate() }
        .onChange(of: total) { _, _ in animate() }
    }

    private func animate() {
        withAnimation(.easeInOut(duration: 0.3)) {
            a = CGFloat(scadonoOggi)
            b = CGFloat(daConsumare)
            c = CGFloat(neiProssimiGiorni)
            d = CGFloat(tuttoOk)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ExpiryControlCardView(
            suggestion: .consumeTodayOne(name: "latte"),
            subtitle: "Frigorifero • 1 pz",
            scadonoOggi: 1, daConsumare: 0, neiProssimiGiorni: 2, tuttoOk: 5,
            totaleProdottiAttivi: 8
        )
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)

        ExpiryControlCardView(
            suggestion: .incomingSoon,
            scadonoOggi: 0, daConsumare: 0, neiProssimiGiorni: 3, tuttoOk: 4,
            totaleProdottiAttivi: 7
        )
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)

        ExpiryControlCardView(
            suggestion: .noUrgency,
            scadonoOggi: 0, daConsumare: 0, neiProssimiGiorni: 0, tuttoOk: 6,
            totaleProdottiAttivi: 6
        )
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    .padding()
}
