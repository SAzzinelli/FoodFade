import SwiftUI
import SwiftData

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
    @State private var showingKPISettings = false
    @State private var selectedFilter: ExpirationStatus?
    @AppStorage("hasShownFirstAddPrompt") private var hasShownFirstAddPrompt = false
    @AppStorage("hasShownSmartSuggestionsBanner") private var hasShownSmartSuggestionsBanner = false
    @State private var showingSmartSuggestionsBanner = false
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    /// In dark mode logo/titolo sempre arancione; in light segue tema
    private var homeLogoColor: Color {
        colorScheme == .dark ? ThemeManager.naturalHomeLogoColor : (ThemeManager.shared.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor)
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
                        .padding(.bottom, 32)
                    
                    // Summary Cards (riordinabili) con pulsante modifica
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Riepilogo")
                                .font(.system(size: 20, weight: .bold, design: .default))
                            Spacer()
                            Button {
                                showingKPISettings = true
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeManager.shared.primaryColor)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        summaryCardsSection
                    }
                    .padding(.bottom, 24)
                    
                    // Quick Actions
                    quickActionsSection
                        .padding(.bottom, 24)
                    
                    // Recent Items
                    recentItemsSection
                        .padding(.bottom, 24)
                    
                    // Categorie rapide
                    categoriesQuickAccessSection
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
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(homeLogoColor)
                            .font(.system(size: 18))
                        Text("FoodFade")
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .foregroundColor(homeLogoColor)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddFood = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(ThemeManager.shared.primaryColor)
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
            .sheet(isPresented: $showingKPISettings) {
                KPISettingsView(viewModel: viewModel)
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
        let counts = viewModel.activityRingCounts
        let urgentCount = viewModel.expiringToday.count + viewModel.toConsume.count
        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("home.rings.title".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                ActivityRingsView(
                    okCount: counts.ok,
                    inScadenzaCount: counts.inScadenza,
                    expiredCount: counts.expired,
                    size: 120,
                    lineWidth: 10,
                    animationsEnabled: ThemeManager.shared.animationsEnabled
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            Text(progressRingLegend)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.secondary.opacity(0.9))
                .multilineTextAlignment(.center)
            if urgentCount > 0 {
                NavigationLink(value: viewModel.expiringToday.count > 0 ? NavigationDestination.kpiCard(.expiringToday) : NavigationDestination.kpiCard(.toConsume)) {
                    HStack(spacing: 6) {
                        Text("👀")
                        Text(urgentCount == 1 ? "Vai al prodotto" : "Vai ai prodotti")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ThemeManager.shared.primaryColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(ThemeManager.shared.primaryColor.opacity(0.24))
                    .foregroundStyle(ThemeManager.shared.primaryColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Text(progressRingSubtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    /// Vista compatta al posto dell'anello: barre solo dove serve + CTA (senza Fridgy)
    private var compactSummaryView: some View {
        let total = max(1, viewModel.totalActiveItems)
        let a = viewModel.expiringToday.count
        let b = viewModel.toConsume.count
        let c = viewModel.incoming.count
        let d = viewModel.allOk.count
        let urgentCount = a + b
        return VStack(spacing: 14) {
            VStack(spacing: 10) {
                CompactSummaryRow(label: "Scadono oggi", count: a, total: total, color: .red, microIcon: a > 0 ? "exclamationmark.triangle.fill" : nil)
                CompactSummaryRow(label: "Da consumare", count: b, total: total, color: .orange, microIcon: b > 0 ? "fork.knife" : nil)
                CompactSummaryRow(label: "Nei prossimi giorni", count: c, total: total, color: Color(red: 0.85, green: 0.75, blue: 0.2), microIcon: nil)
                CompactSummaryRow(label: "Tutto ok", count: d, total: total, color: .green, microIcon: nil)
            }
            if urgentCount > 0 {
                NavigationLink(value: a > 0 ? NavigationDestination.kpiCard(.expiringToday) : NavigationDestination.kpiCard(.toConsume)) {
                    HStack(spacing: 6) {
                        Text("👀")
                        Text(urgentCount == 1 ? "Vai al prodotto" : "Vai ai prodotti")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ThemeManager.shared.primaryColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(ThemeManager.shared.primaryColor.opacity(0.24))
                    .foregroundStyle(ThemeManager.shared.primaryColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Text(progressRingSubtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
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
        case .healthScore:
            return "Il tuo andamento"
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
            
        case .healthScore:
            if percentage >= 0.8 {
                return "Ottimo"
            } else if percentage >= 0.5 {
                return "Buono"
            } else if percentage > 0 {
                return "Da migliorare"
            } else {
                return "Nessun dato"
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
            
        case .healthScore:
            let descriptor = FetchDescriptor<FoodItem>()
            guard let allItems = try? modelContext.fetch(descriptor) else { return "⏳ Un attimo…" }
            
            let consumed = allItems.filter { $0.isConsumed }.count
            let expired = allItems.filter { !$0.isConsumed && $0.expirationStatus == .expired }.count
            
            if consumed == 0 && expired == 0 {
                return "📊 Aggiungi prodotti per vedere il tuo andamento"
            } else if expired == 0 {
                return "🎉 Ottimo, niente sprechi!"
            } else {
                return "📈 \(consumed) consumati, \(expired) scaduti"
            }
        }
    }
    
    // MARK: - Summary Cards Section (KPI – layout semplice)
    private var summaryCardsSection: some View {
        VStack(spacing: 12) {
            if viewModel.kpiCardOrder.count >= 2 {
                HStack(spacing: 12) {
                    NavigationLink(value: NavigationDestination.kpiCard(viewModel.kpiCardOrder[0])) {
                        SummaryCardContent(
                            type: viewModel.kpiCardOrder[0],
                            count: viewModel.count(for: viewModel.kpiCardOrder[0])
                        )
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: NavigationDestination.kpiCard(viewModel.kpiCardOrder[1])) {
                        SummaryCardContent(
                            type: viewModel.kpiCardOrder[1],
                            count: viewModel.count(for: viewModel.kpiCardOrder[1])
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            if viewModel.kpiCardOrder.count >= 3 {
                HStack(spacing: 12) {
                    NavigationLink(value: NavigationDestination.kpiCard(viewModel.kpiCardOrder[2])) {
                        SummaryCardContent(
                            type: viewModel.kpiCardOrder[2],
                            count: viewModel.count(for: viewModel.kpiCardOrder[2])
                        )
                    }
                    .buttonStyle(.plain)
                    if viewModel.kpiCardOrder.count >= 4 {
                        NavigationLink(value: NavigationDestination.kpiCard(viewModel.kpiCardOrder[3])) {
                            SummaryCardContent(
                                type: viewModel.kpiCardOrder[3],
                                count: viewModel.count(for: viewModel.kpiCardOrder[3])
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Azioni Rapide")
                .font(.system(size: 20, weight: .bold, design: .default))
                .padding(.horizontal, 4)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "barcode.viewfinder",
                    title: "Scansiona",
                    color: ThemeManager.shared.primaryColor
                ) {
                    showingScanner = true
                }
                
                NavigationLink(value: NavigationDestination.expiringSoon) {
                    QuickActionButtonContent(
                        icon: "clock.badge.exclamationmark.fill",
                        title: "Scadenza a breve",
                        color: ThemeManager.shared.primaryColor
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Categories Quick Access Section
    private var categoriesQuickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categorie")
                .font(.system(size: 20, weight: .bold, design: .default))
                .padding(.horizontal, 4)
            
            HStack(spacing: 12) {
                CategoryQuickButton(
                    category: .fridge,
                    icon: "refrigerator.fill",
                    count: allItems.filter { $0.category == .fridge && !$0.isConsumed }.count
                )
                
                CategoryQuickButton(
                    category: .freezer,
                    icon: "snowflake",
                    count: allItems.filter { $0.category == .freezer && !$0.isConsumed }.count
                )
                
                CategoryQuickButton(
                    category: .pantry,
                    icon: "cabinet.fill",
                    count: allItems.filter { $0.category == .pantry && !$0.isConsumed }.count
                )
            }
        }
    }
    
    // MARK: - Recent Items Section
    private var recentItemsSection: some View {
        let recentItems = Array(allItems.filter { !$0.isConsumed }.prefix(5))
        
        guard !recentItems.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Prodotti Recenti")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .padding(.horizontal, 4)
                
                VStack(spacing: 8) {
                    ForEach(recentItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            RecentItemRow(item: item)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        )
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

// MARK: - Summary Card Content (KPI – icona + titolo + numero + micro-label emotiva)
private struct SummaryCardContent: View {
    let type: KPICardType
    let count: Int
    
    @State private var animatedCount: Int = 0
    @State private var glowIntensity: Double = 0.5
    
    private var microLabel: String {
        switch type {
        case .expiringToday: return count == 0 ? "Ottimo!" : "Da gestire"
        case .toConsume: return count == 0 ? "Tranquillo" : "Da gestire"
        case .incoming: return count == 0 ? "Tranquillo" : "Presto"
        case .allOk: return count == 0 ? "—" : "Tutto ok"
        }
    }
    
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
            
            Text(microLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
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

// MARK: - Quick Action Button
private struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            QuickActionButtonContent(icon: icon, title: title, color: color)
        }
        .buttonStyle(.plain)
    }
}

private struct QuickActionButtonContent: View {
    let icon: String
    let title: String
    let color: Color
    
    /// In stile Naturale usiamo Color.primary così le icone sono chiare in dark mode
    private var iconColor: Color {
        ThemeManager.shared.isNaturalStyle ? Color.primary : color
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
            
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Category Quick Button
private struct CategoryQuickButton: View {
    let category: FoodCategory
    let icon: String
    let count: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(colorForCategory(category))
            
            Text(category.rawValue)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .default))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func colorForCategory(_ category: FoodCategory) -> Color {
        switch category {
        case .fridge: return .blue
        case .freezer: return .cyan
        case .pantry: return .orange
        }
    }
}

// MARK: - Recent Item Row
private struct RecentItemRow: View {
    let item: FoodItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForCategory(item.category))
                .font(.system(size: 20))
                .foregroundColor(colorForCategory(item.category))
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                
                Text(item.expirationStatus.displayName)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(daysText)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var daysText: String {
        let days = item.daysRemaining
        if days < 0 {
            return "Scaduto"
        } else if days == 0 {
            return "Scade oggi"
        } else if days == 1 {
            return "Scade tra 1 giorno"
        } else {
            return "Scade tra \(days) giorni"
        }
    }
    
    private var statusColor: Color {
        switch item.expirationStatus {
        case .expired, .today: return AppTheme.accentRed
        case .soon: return AppTheme.accentOrange
        case .safe: return AppTheme.primaryGreen
        }
    }
    
    private func iconForCategory(_ category: FoodCategory) -> String {
        switch category {
        case .fridge: return "refrigerator.fill"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet.fill"
        }
    }
    
    private func colorForCategory(_ category: FoodCategory) -> Color {
        switch category {
        case .fridge: return .blue
        case .freezer: return .cyan
        case .pantry: return .orange
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
                    ForEach(Array(viewModel.kpiCardOrder.enumerated()), id: \.element) { index, kpiType in
                        Text(kpiType.title)
                    }
                    .onMove { source, destination in
                        viewModel.moveKPI(from: source, to: destination)
                    }
                } footer: {
                    Text("Trascina le sezioni per riordinarle. L'ordine che imposti verrà visualizzato nella schermata Home.")
                        .font(.system(size: 13))
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
