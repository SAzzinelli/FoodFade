import SwiftUI
import SwiftData

/// Vista per mostrare i prodotti filtrati per status KPI
struct KPIStatusView: View {
    let status: ExpirationStatus
    
    private var filterStatus: ExpirationStatus? {
        // Ritorna lo status direttamente - InventoryView gestirà il caso .today per includere anche .expired
        return status
    }
    
    private var title: String {
        switch status {
        case .expired, .today:
            return "Scadono Oggi"
        case .soon:
            return "Prossimi alla Scadenza"
        case .safe:
            return "Prodotti Sicuri"
        }
    }
    
    var body: some View {
        InventoryView(filterStatus: filterStatus)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        KPIStatusView(status: .safe)
            .modelContainer(for: FoodItem.self)
    }
}

