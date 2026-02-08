import SwiftUI
import SwiftData
import UIKit

/// Destinazione di navigazione
enum NavigationDestination: Hashable {
    case inventory
    case expiringSoon
    case category(FoodCategory)
    case kpiCard(KPICardType) // Per le sottoviste dei KPI
}

/// Vista principale - Dashboard
struct HomeView: View {
    @Query(sort: \FoodItem.expirationDate, order: .forward) private var allItems: [FoodItem]
    @Query private var userProfiles: [UserProfile]
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var scannerService = BarcodeScannerService()
    @State private var showingAddFood = false
    @State private var showingScanner = false
    @State private var selectedFilter: ExpirationStatus?
    @AppStorage("hasShownFirstAddPrompt") private var hasShownFirstAddPrompt = false
    @AppStorage("hasShownSmartSuggestionsBanner") private var hasShownSmartSuggestionsBanner = false
    @State private var showingSmartSuggestionsBanner = false
    @State private var categoriesAccordionExpanded = true
    @State private var recentItemsAccordionExpanded = true
    @State private var categoryToOpen: FoodCategory?
    @State private var showExpiringSoonView = false
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    /// In dark mode logo/titolo sempre arancione; in light segue tema
    private var homeLogoColor: Color {
        colorScheme == .dark ? ThemeManager.naturalHomeLogoColor : (ThemeManager.shared.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor)
    }
    
    /// Colore anello e CTA in Home: arancione in stile Naturale, altrimenti primary
    private var homeAccentColor: Color {
        ThemeManager.shared.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor
    }
    
    private var userName: String {
        userProfiles.first?.displayName ?? "Utente"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    headerSection
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    
                    // Progress Section
                    progressSection
                        .padding(.bottom, 24)
                    
                    // 3 KPI: Totale, Scaduti, In scadenza
                    homeKPIRow
                        .padding(.bottom, 24)
                    
                    // Prodotti in scadenza (scroll orizzontale card)
                    expiringProductsSection
                        .padding(.bottom, 24)
                    
                    // Categorie (accordion)
                    categoriesAccordionSection
                        .padding(.bottom, 24)
                    
                    // Prodotti recenti (accordion)
                    recentItemsAccordionSection
                        .padding(.bottom, 24)
                    
                    // Banner informativo suggerimenti intelligenti (mostrato una volta dopo aver aggiunto/modificato un oggetto)
                    if showingSmartSuggestionsBanner && !hasShownSmartSuggestionsBanner {
                        smartSuggestionsInfoBanner
                            .padding(.bottom, 24)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(ThemeManager.naturalHomeLogoColor)
                        Text("FoodFade")
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .foregroundColor(ThemeManager.naturalHomeLogoColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                AddFoodView()
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView(scannerService: scannerService) { barcode in
                    // Quando viene scansionato un codice, apri AddFoodView con il barcode
                    showingScanner = false
                    showingAddFood = true
                    // TODO: Passare il barcode a AddFoodView
                }
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
                viewModel.loadData()
                
                // Se iCloud è abilitato, forza un refresh per sincronizzare i dati
                let useiCloud = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
                if useiCloud {
                    Task {
                        // Attendi un po' per permettere a CloudKit di sincronizzare
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondi
                        await MainActor.run {
                            // Forza un save per triggerare la sincronizzazione
                            try? modelContext.save()
                            // Ricarica i dati
                            viewModel.loadData()
                            print("☁️ HomeView - Refresh dati dopo sincronizzazione CloudKit")
                        }
                    }
                }
            }
            .onChange(of: allItems.count) { oldValue, newValue in
                viewModel.loadData()
                
                // Mostra il banner informativo quando viene aggiunto un nuovo oggetto
                if newValue > oldValue && !hasShownSmartSuggestionsBanner {
                    showingSmartSuggestionsBanner = true
                }
            }
            .onChange(of: viewModel.smartSuggestion) { oldValue, newValue in
                // Mostra il banner informativo quando viene generato un suggerimento intelligente per la prima volta
                if newValue != nil && oldValue == nil && !hasShownSmartSuggestionsBanner {
                    showingSmartSuggestionsBanner = true
                }
            }
            .onChange(of: settings.first?.progressRingModeRaw) { oldValue, newValue in
                // Ricarica i dati quando cambia la modalità dell'anello
                viewModel.loadData()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .inventory:
                    InventoryView(filterStatus: nil)
                case .expiringSoon:
                    ExpiringSoonView()
                case .category(let category):
                    CategoryInventoryView(category: category)
                case .kpiCard(let kpiType):
                    switch kpiType {
                    case .expiringToday:
                        ExpiringTodayView()
                    case .toConsume:
                        ToConsumeView()
                    case .incoming:
                        IncomingView()
                    case .allOk:
                        AllOkView()
                    }
                }
            }
            .navigationDestination(item: $categoryToOpen) { category in
                CategoryInventoryView(category: category)
            }
            .navigationDestination(isPresented: $showExpiringSoonView) {
                ExpiringSoonView()
            }
        }
        .tint(ThemeManager.shared.primaryColor)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        Text(greetingText)
            .font(.system(size: 34, weight: .bold, design: .default))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var greetingText: String {
        let greeting = "home.greeting.ciao".localized
        return "\(greeting), \(userName)!"
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 16) {
            if viewModel.totalActiveItems == 0 {
                progressEmptyState
            } else if currentHomeSummaryStyle == .compact {
                compactSummaryView
            } else {
                progressSectionWithRing
            }
        }
    }
    
    private var progressSectionWithRing: some View {
        let percentage = viewModel.progressRingPercentage
        return VStack(spacing: 16) {
            VStack(spacing: 24) {
                AnimatedProgressRing(
                    progress: percentage,
                    size: 140,
                    lineWidth: 20,
                    ringColor: homeAccentColor,
                    unfilledOpacity: 0.15,
                    animationsEnabled: ThemeManager.shared.animationsEnabled
                ) {
                    VStack(spacing: 4) {
                        Text("\(Int(round(percentage * 100)))%")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.primary)
                        Text(progressRingLabel)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                Text(progressRingSubtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
    
    /// Vista compatta al posto dell'anello: barre solo dove serve + CTA (senza Fridgy)
    private var compactSummaryView: some View {
        let total = max(1, viewModel.totalActiveItems)
        let a = viewModel.expiringToday.count
        let b = viewModel.toConsume.count
        let c = viewModel.incoming.count
        let d = viewModel.allOk.count
        return VStack(spacing: 14) {
            VStack(spacing: 10) {
                CompactSummaryRow(label: "Scadono oggi", count: a, total: total, color: .red, microIcon: a > 0 ? "exclamationmark.triangle.fill" : nil)
                CompactSummaryRow(label: "Da consumare", count: b, total: total, color: .orange, microIcon: b > 0 ? "fork.knife" : nil)
                CompactSummaryRow(label: "Nei prossimi giorni", count: c, total: total, color: Color(red: 0.85, green: 0.75, blue: 0.2), microIcon: nil)
                CompactSummaryRow(label: "Tutto ok", count: d, total: total, color: .green, microIcon: nil)
            }
            Text(progressRingSubtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    /// Placeholder al posto dell'anello quando non ci sono prodotti
    private var progressEmptyState: some View {
        VStack(spacing: 12) {
            Text("📦 \("home.progress.empty.title".localized)")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundColor(.primary)
            
            Text("✨ \("home.progress.empty.subtitle".localized)")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Progress Ring Helpers
    @Query private var settings: [AppSettings]
    
    private var currentProgressRingMode: ProgressRingMode {
        settings.first?.progressRingMode ?? .safeItems
    }
    
    private var currentHomeSummaryStyle: HomeSummaryStyle {
        settings.first?.homeSummaryStyle ?? .ring
    }
    
    /// Didascalia sotto l'anello (user friendly)
    private var progressRingLegend: String {
        switch currentProgressRingMode {
        case .safeItems:
            return "Quanto sei in tempo con le scadenze"
        case .atRisk:
            return "Quanto è sotto controllo"
        }
    }
    
    /// Testo dentro l'anello (senza emoji; le emoji restano solo sotto nel subtitle)
    private var progressRingLabel: String {
        let percentage = viewModel.progressRingPercentage
        
        switch currentProgressRingMode {
        case .safeItems:
            if percentage >= 0.8 {
                return "Tutto ok"
            } else if percentage >= 0.5 {
                return "Quasi tutto ok"
            } else if percentage > 0 {
                return "Attenzione"
            } else {
                return "Da controllare"
            }
            
        case .atRisk:
            if percentage == 0.0 {
                return "Nessun rischio"
            } else if percentage <= 0.2 {
                return "Basso rischio"
            } else if percentage <= 0.5 {
                return "Rischio medio"
            } else {
                return "Alto rischio"
            }
        }
    }
    
    private var progressRingSubtitle: String {
        let percentage = viewModel.progressRingPercentage
        let urgentCount = viewModel.expiringToday.count + viewModel.toConsume.count
        
        switch currentProgressRingMode {
        case .safeItems:
            if percentage == 1.0 {
                return "😌 Tutto tranquillo!"
            } else if urgentCount > 0 {
                if urgentCount == 1 {
                    return "👀 C’è un prodotto da tenere d’occhio"
                } else {
                    return "👀 Qualche prodotto da tenere d’occhio"
                }
            } else if viewModel.incoming.count > 0 {
                return "📅 Qualche scadenza in vista"
            } else {
                return "🔍 Dai un’occhiata alle scadenze"
            }
            
        case .atRisk:
            let atRiskCount = viewModel.expiringToday.count + viewModel.toConsume.count + viewModel.incoming.count
            if percentage == 0.0 {
                return "😊 Tutto sotto controllo"
            } else if atRiskCount == 1 {
                return "⚠️ Un prodotto da non dimenticare"
            } else {
                return "⚠️ \(atRiskCount) prodotti da tenere d’occhio"
            }
        }
    }
    
    // MARK: - 3 KPI (Totale, Scaduti, In scadenza)
    private var homeKPIRow: some View {
        HStack(spacing: 12) {
            HomeKPICard(
                icon: "square.stack.3d.up.fill",
                label: "home.kpi.total".localized,
                value: viewModel.totalActiveItems,
                color: .green
            )
            HomeKPICard(
                icon: "trash.fill",
                label: "home.kpi.expired".localized,
                value: viewModel.expiredCount,
                color: .red
            )
            HomeKPICard(
                icon: "clock.fill",
                label: "home.kpi.expiring".localized,
                value: viewModel.inScadenzaCount,
                color: .orange
            )
        }
    }
    
    // MARK: - Prodotti in scadenza (scroll orizzontale)
    private var expiringItems: [FoodItem] {
        let combined = viewModel.expiringToday + viewModel.toConsume + viewModel.incoming
        return combined.sorted { $0.effectiveExpirationDate < $1.effectiveExpirationDate }
    }
    
    private var expiringProductsSection: some View {
        let items = Array(expiringItems.prefix(15))
        return Group {
            if items.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("home.expiring.section.title".localized)
                            .font(.system(size: 20, weight: .bold, design: .default))
                        Spacer()
                        Button {
                            showExpiringSoonView = true
                        } label: {
                            Text("home.see.all".localized)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(ThemeManager.shared.primaryColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(items) { item in
                                NavigationLink {
                                    ItemDetailView(item: item)
                                } label: {
                                    ExpiringProductCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Categorie (accordion, card verticali con icona, titolo, sottotitolo, chevron)
    private func expiringCount(for category: FoodCategory) -> Int {
        viewModel.expiringToday.filter { $0.category == category }.count
        + viewModel.toConsume.filter { $0.category == category }.count
        + viewModel.incoming.filter { $0.category == category }.count
    }
    
    private var categoriesAccordionSection: some View {
        DisclosureGroup(isExpanded: $categoriesAccordionExpanded) {
            VStack(spacing: 10) {
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    Button {
                        categoryToOpen = category
                    } label: {
                        HomeCategoryCard(
                            category: category,
                            productCount: allItems.filter { $0.category == category && !$0.isConsumed }.count,
                            expiringCount: expiringCount(for: category)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        } label: {
            Text("Categorie")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundColor(.primary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Prodotti recenti (accordion)
    private var recentItemsAccordionSection: some View {
        let recentItems = Array(allItems.filter { !$0.isConsumed }.sorted { $0.createdAt > $1.createdAt }.prefix(5))
        
        return Group {
            if recentItems.isEmpty {
                DisclosureGroup(isExpanded: $recentItemsAccordionExpanded) {
                    Text("home.recent.empty".localized)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                } label: {
                    Text("Prodotti recenti")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                DisclosureGroup(isExpanded: $recentItemsAccordionExpanded) {
                    VStack(spacing: 10) {
                        ForEach(recentItems) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                HomeRecentProductRow(item: item)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Prodotti recenti")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Smart Suggestions Info Banner
    private var smartSuggestionsInfoBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(ThemeManager.shared.primaryColor)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggerimenti Intelligenti")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.primary)
                    
                    Text("FoodFade analizza i tuoi prodotti e ti suggerisce quando consumarli per ridurre gli sprechi. I suggerimenti appaiono qui in base alle tue abitudini.")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Button {
                    hasShownSmartSuggestionsBanner = true
                    showingSmartSuggestionsBanner = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Smart Suggestion Card
    private func smartSuggestionCard(_ suggestion: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundColor(ThemeManager.shared.primaryColor)
                .frame(width: 32, height: 32)
            
            Text(suggestion)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Riga con barra per il riepilogo compatto (evidenzia solo non-zero)
private struct CompactSummaryRow: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    var microIcon: String? = nil
    
    private var fillRatio: CGFloat {
        min(1, CGFloat(count) / CGFloat(max(1, total)))
    }
    
    private var isZero: Bool { count == 0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let icon = microIcon, count > 0 {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isZero ? .secondary : .primary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 14, weight: isZero ? .regular : .semibold, design: .rounded))
                    .foregroundColor(isZero ? Color(.tertiaryLabel) : color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(isZero ? 0.06 : 0.08))
                    if count > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.opacity(0.9))
                            .frame(width: max(0, geo.size.width * fillRatio))
                    }
                }
            }
            .frame(height: isZero ? 4 : 6)
        }
    }
}

// MARK: - Card KPI Home (Totale, Scaduti, In scadenza)
private struct HomeKPICard: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Card prodotto in scadenza (scroll orizzontale Home)
private struct ExpiringProductCard: View {
    let item: FoodItem
    
    private var badgeText: String {
        let days = item.daysRemaining
        if days < 0 { return "Scaduto" }
        if days == 0 { return "Oggi" }
        if days == 1 { return "Domani" }
        return "\(days) gg"
    }
    
    private var badgeColor: Color {
        switch item.expirationStatus {
        case .expired: return .red
        case .today: return .orange
        case .soon: return .orange
        case .safe: return .green
        }
    }
    
    private var categoryColor: Color {
        AppTheme.color(for: item.category)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                imageView
                    .frame(width: 140, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(badgeText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeColor)
                    .clipShape(Capsule())
                    .padding(8)
            }
            Text(item.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
            Text("\(item.category.rawValue) • \(item.quantity) pz")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
        }
        .frame(width: 140, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var imageView: some View {
        Group {
            if let data = item.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: item.category.iconFill)
                    .font(.system(size: 36))
                    .foregroundColor(categoryColor.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(categoryColor.opacity(0.12))
            }
        }
    }
}

// MARK: - Summary Card Content (KPI – icona + titolo + numero)
private struct SummaryCardContent: View {
    let type: KPICardType
    let count: Int
    
    @State private var animatedCount: Int = 0
    @State private var glowIntensity: Double = 0.5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(type.color)
                .clipShape(Circle())
            
            Text(type.title)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(.secondary)
            
            Text("\(animatedCount)")
                .font(.system(size: 32, weight: .bold, design: .default))
                .foregroundColor(type.color)
                .opacity(type == .allOk && animatedCount == 0 ? 0.4 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(
            color: type == .toConsume && animatedCount > 0 ? type.color.opacity(0.2 * glowIntensity) : Color.clear,
            radius: type == .toConsume && animatedCount > 0 ? 8 * glowIntensity : 0,
            x: 0,
            y: type == .toConsume && animatedCount > 0 ? 2 * glowIntensity : 0
        )
        .scaleEffect(type == .toConsume && animatedCount > 0 ? 1.02 : 1.0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { animatedCount = count }
            if type == .toConsume && count > 0 {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { glowIntensity = 1.0 }
            }
        }
        .onChange(of: count) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.5)) { animatedCount = newValue }
            if type == .toConsume && newValue == 0 { glowIntensity = 0.5 }
            else if type == .toConsume && newValue > 0 && oldValue == 0 {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { glowIntensity = 1.0 }
            }
        }
    }
}

// MARK: - Summary Card Component (con Button per usi diversi)
private struct SummaryCardView: View {
    let type: KPICardType
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            SummaryCardContent(type: type, count: count)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card categoria Home (icona, titolo, X Prodotti • Y in scadenza / Tutto OK, chevron)
private struct HomeCategoryCard: View {
    let category: FoodCategory
    let productCount: Int
    let expiringCount: Int
    
    private var categoryColor: Color {
        AppTheme.color(for: category)
    }
    
    private var iconName: String {
        switch category {
        case .fridge: return "refrigerator.fill"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet.fill"
        }
    }
    
    private var subtitle: String {
        let products = String(format: "home.category.products".localized, productCount)
        if expiringCount == 0 {
            return "\(products) \("home.category.all_ok".localized)"
        }
        return "\(products) \(String(format: "home.category.expiring".localized, expiringCount))"
    }
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(categoryColor)
                .frame(width: 48, height: 48)
                .background(categoryColor.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.rawValue)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Riga prodotto recente (immagine tonda, nome, Aggiunto oggi/ieri, pill categoria)
private struct HomeRecentProductRow: View {
    let item: FoodItem
    
    private var categoryColor: Color {
        AppTheme.color(for: item.category)
    }
    
    private var addedText: String {
        let cal = Calendar.current
        if cal.isDateInToday(item.createdAt) {
            return "home.recent.added_today".localized
        }
        if cal.isDateInYesterday(item.createdAt) {
            return "home.recent.added_yesterday".localized
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: item.createdAt)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            imageView
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(addedText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(item.category.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(categoryColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(categoryColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var imageView: some View {
        Group {
            if let data = item.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: item.category.iconFill)
                    .font(.system(size: 22))
                    .foregroundColor(categoryColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(categoryColor.opacity(0.12))
            }
        }
    }
}

// MARK: - KPI Settings View
struct KPISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Image("FridgyBravo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 160, maxHeight: 160)
                            .frame(maxWidth: .infinity)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Riordina le card del Riepilogo")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Decidi in che ordine mostrare le quattro sezioni nella schermata Home.")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                .listRowBackground(Color(.secondarySystemGroupedBackground))
                
                Section {
                    ForEach(Array(viewModel.kpiCardOrder.enumerated()), id: \.element) { index, kpiType in
                        Text(kpiType.title)
                    }
                    .onMove { source, destination in
                        viewModel.moveKPI(from: source, to: destination)
                    }
                }
            }
            .navigationTitle("Riordina sezioni veloci")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))
        }
    }
}

// MARK: - Category Inventory View
struct CategoryInventoryView: View {
    let category: FoodCategory
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [FoodItem]
    
    private var filteredItems: [FoodItem] {
        allItems.filter { $0.category == category && !$0.isConsumed }
    }
    
    var body: some View {
        InventoryView(filterStatus: nil, categoryFilter: category)
    }
}

// Estensione per ExpirationStatus
extension ExpirationStatus {
    var displayName: String {
        switch self {
        case .expired: return "Scaduto"
        case .today: return "Scade oggi"
        case .soon: return "In scadenza"
        case .safe: return "Sicuro"
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [FoodItem.self, UserProfile.self])
}
