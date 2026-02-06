import SwiftUI
import SwiftData
import Charts

/// Periodo per le statistiche (allineato agli screen)
enum StatisticsPeriod: String, CaseIterable {
    case week = "Settimana"
    case month = "Mese"
}

/// Vista delle statistiche - UI/UX basata su screen (Waste Score, grafico, per categoria, dettagli)
struct StatisticsView: View {
    @Query(sort: \FoodItem.createdAt, order: .reverse) private var allItems: [FoodItem]
    @Query private var userProfiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var themeManager = ThemeManager.shared
    @State private var statsData: StatisticsData?
    @State private var selectedPeriod: StatisticsPeriod = .month
    @State private var animatedWasteScore: Double = 0.0
    @State private var fridgyInsights: [(message: String, context: FridgyContext)] = []
    @State private var isLoadingFridgy: Bool = false
    private let fridgyService: FridgyService = FridgyServiceImpl.shared
    
    private var userGender: GenderHelper.Gender {
        GenderHelper.getGender(from: userProfiles.first)
    }
    
    private var primaryColor: Color {
        themeManager.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : themeManager.primaryColor
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let data = statsData {
                    VStack(spacing: 24) {
                        // Selector periodo
                        periodSelector
                        
                        // Riepilogo Consumati | Scaduti
                        summaryRow(data: data)
                        
                        // Waste Score (anello, emoji, Perfetto!, spiegazione, Continua così)
                        wasteScoreCard(data: data)
                        
                        // Grafico Cibo usato vs sprecato
                        if data.hasChartData {
                            usedVsWastedChartCard(data: data)
                        }
                        
                        // Per categoria
                        if data.hasCategoryStats {
                            categoryCard(data: data)
                        }
                        
                        // Quanto tieni i prodotti
                        if data.averageConsumptionDays != nil {
                            averageDaysCard(data: data)
                        }
                        
                        // Dettagli - Prodotti più aggiunti
                        if data.hasDetails {
                            detailsCard(data: data)
                        }
                        
                        // Fridgy (se disponibile)
                        if IntelligenceManager.shared.isFridgyAvailable {
                            fridgyInsightsSection(data: data)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                } else {
                    emptyState
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistiche")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        calculateStatistics()
                        loadFridgyInsights()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18))
                            .foregroundColor(primaryColor)
                    }
                }
            }
            .tint(primaryColor)
            .onAppear {
                calculateStatistics()
                loadFridgyInsights()
            }
            .onChange(of: allItems.count) { _, _ in
                calculateStatistics()
                loadFridgyInsights()
            }
            .onChange(of: selectedPeriod) { _, _ in
                calculateStatistics()
            }
        }
    }
    
    private var periodSelector: some View {
        VStack(spacing: 8) {
            Picker("Periodo", selection: $selectedPeriod) {
                ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            Text("Tocca per cambiare periodo")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
    
    private func summaryRow(data: StatisticsData) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(data.monthlyStats.consumed)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Consumati")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            
            HStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(data.monthlyStats.expired)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Scaduti")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Waste Score Card (anello, emoji, Perfetto!, spiegazione, Continua così)
    private func wasteScoreCard(data: StatisticsData) -> some View {
        VStack(spacing: 16) {
            Text("Waste Score")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 18)
                    .frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: animatedWasteScore)
                    .stroke(
                        LinearGradient(
                            colors: [primaryColor, themeManager.primaryColorDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 160, height: 160)
                    .animation(.spring(response: 1.5, dampingFraction: 0.8), value: animatedWasteScore)
                
                VStack(spacing: 6) {
                    Text(wasteScoreEmoji(percentage: data.wasteScore))
                        .font(.system(size: 40))
                    Text("\(Int(animatedWasteScore * 100))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            
            Text(wasteScoreTitle(percentage: data.wasteScore))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            Text("\(Int(data.wasteScore * 100))% di spreco evitato")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            Text(wasteScoreSubtitle(wastedCount: data.monthlyStats.expired))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Quanto hai usato in tempo rispetto a quanto è scaduto. 100% = hai consumato tutto prima della scadenza; più basso = più prodotti scaduti senza uso.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Continua così") { }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(primaryColor)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .onAppear {
            withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) { animatedWasteScore = data.wasteScore }
        }
        .onChange(of: data.wasteScore) { _, newValue in
            withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) { animatedWasteScore = newValue }
        }
    }
    
    private func wasteScoreEmoji(percentage: Double) -> String {
        if percentage >= 1.0 { return "🎉" }
        if percentage >= 0.8 { return "👍" }
        return "⚠️"
    }
    
    private func wasteScoreTitle(percentage: Double) -> String {
        if percentage >= 1.0 { return "Perfetto!" }
        if percentage >= 0.8 { return "Quasi perfetto" }
        return "Attenzione agli sprechi"
    }
    
    // MARK: - Chart Cibo usato vs sprecato (bar chart)
    private func usedVsWastedChartCard(data: StatisticsData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cibo usato vs sprecato")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            Text("Confronto tra prodotti consumati e scaduti")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            if let weeklyData = data.weeklyData {
                Chart(weeklyData) { point in
                    BarMark(x: .value("Data", point.dateLabel), y: .value("Consumati", point.consumed))
                        .foregroundStyle(primaryColor)
                    BarMark(x: .value("Data", point.dateLabel), y: .value("Scaduti", point.expired))
                        .foregroundStyle(.red)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel().font(.system(size: 11))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.system(size: 11))
                    }
                }
                .frame(height: 200)
                
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(primaryColor)
                            .frame(width: 12, height: 12)
                        Text("Consumati").font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("Scaduti").font(.system(size: 13)).foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Per categoria
    private func categoryCard(data: StatisticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Per categoria")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            ForEach(data.categoryStats, id: \.category) { stat in
                HStack(spacing: 12) {
                    Image(systemName: stat.category.iconFill)
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.color(for: stat.category))
                        .frame(width: 32)
                    Text(stat.category.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    if stat.total > 0 && stat.consumed == stat.total {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("100% ok")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 8)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(primaryColor)
                                .frame(width: stat.total > 0 ? geo.size.width * CGFloat(stat.consumed) / CGFloat(stat.total) : 0, height: 8)
                        }
                    }
                    .frame(width: 60, height: 8)
                    Text("\(stat.consumed)/\(stat.total)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Quanto tieni i prodotti
    private func averageDaysCard(data: StatisticsData) -> some View {
        guard let avgDays = data.averageConsumptionDays else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Quanto tieni i prodotti")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(primaryColor.opacity(0.3), lineWidth: 2)
                            .frame(width: 48, height: 48)
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 22))
                            .foregroundColor(primaryColor)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("In media li consumi dopo")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        HStack(spacing: 8) {
                            Text("\(avgDays)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(primaryColor)
                                .clipShape(Circle())
                            Text(avgDays == 1 ? "giorno" : "giorni")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        )
    }
    
    // MARK: - Dettagli (Prodotti più aggiunti con numeri arancioni)
    private func detailsCard(data: StatisticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dettagli")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            Text("Prodotti più aggiunti")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            if data.topAddedProducts.isEmpty {
                Text("I dettagli compariranno man mano che usi l'app")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(data.topAddedProducts.prefix(5).enumerated()), id: \.element.name) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(primaryColor)
                            .clipShape(Circle())
                        Text(item.name)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(item.count)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Nessun dato disponibile")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            Text("Aggiungi qualche prodotto per iniziare")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Helper Functions
    private func wasteScoreLabel(percentage: Double) -> String {
        let percent = Int(percentage * 100)
        if percent == 100 {
            return "Tutto ok"
        } else if percent >= 80 {
            return "Qualche spreco"
        } else {
            return "Attenzione agli sprechi"
        }
    }
    
    private func wasteScoreSubtitle(wastedCount: Int) -> String {
        if wastedCount == 0 {
            return "Nessun prodotto scaduto questo mese"
        } else {
            return "\(wastedCount) \(wastedCount == 1 ? "prodotto scaduto" : "prodotti scaduti") questo mese"
        }
    }
    
    // MARK: - Statistics Calculation
    private func calculateStatistics() {
        let calendar = Calendar.current
        let now = Date()
        
        let periodStart: Date
        switch selectedPeriod {
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            periodStart = startOfWeek
        case .month:
            periodStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        }
        
        let periodItems = allItems.filter { $0.createdAt >= periodStart }
        
        guard !allItems.isEmpty else {
            statsData = nil
            return
        }
        
        var consumed = 0
        var expired = 0
        var expiringSoon = 0
        for item in periodItems {
            if item.isConsumed {
                consumed += 1
            } else {
                if item.expirationStatus == .expired { expired += 1 }
                else if item.expirationStatus == .soon || item.expirationStatus == .today { expiringSoon += 1 }
            }
        }
        
        let monthlyStats = MonthlyStats(consumed: consumed, expired: expired, expiringSoon: expiringSoon)
        let total = consumed + expired
        let wasteScore = total > 0 ? Double(consumed) / Double(total) : 1.0
        
        let recentTrend = calculateRecentTrend(calendar: calendar, now: now)
        let avgDays = calculateAverageConsumptionDays(items: allItems.filter { $0.isConsumed })
        let wasteByType = calculateWasteByType(items: allItems)
        let advice = generateWeeklyAdvice(monthlyStats: monthlyStats, wasteByType: wasteByType, avgDays: avgDays)
        let topAdded = calculateTopProducts(items: allItems, filterConsumed: false)
        let topWasted = calculateTopProducts(items: allItems.filter { !$0.isConsumed && $0.expirationStatus == .expired }, filterConsumed: false)
        let weeklyData = calculateWeeklyData(calendar: calendar, now: now)
        let categoryStats = calculateCategoryStats(items: periodItems)
        
        statsData = StatisticsData(
            wasteScore: wasteScore,
            monthlyStats: monthlyStats,
            recentTrendMessage: recentTrend.message,
            hasRecentTrend: recentTrend.hasData,
            averageConsumptionDays: avgDays,
            wasteByType: wasteByType,
            weeklyAdvice: advice,
            topAddedProducts: topAdded,
            topWastedProducts: topWasted,
            weeklyData: weeklyData,
            categoryStats: categoryStats
        )
    }
    
    private func calculateCategoryStats(items: [FoodItem]) -> [CategoryStat] {
        FoodCategory.allCases.map { category in
            let inCategory = items.filter { $0.category == category }
            let consumed = inCategory.filter { $0.isConsumed }.count
            let total = inCategory.count
            return CategoryStat(category: category, consumed: consumed, total: total)
        }.filter { $0.total > 0 }
    }
    
    private func calculateRecentTrend(calendar: Calendar, now: Date) -> (message: String, hasData: Bool) {
        // Ultime 2 settimane
        guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now),
              let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return ("Situazione stabile nelle ultime settimane", false)
        }
        
        let firstWeek = allItems.filter { item in
            !item.isConsumed && item.expirationStatus == .expired &&
            item.createdAt >= twoWeeksAgo && item.createdAt < oneWeekAgo
        }
        
        let secondWeek = allItems.filter { item in
            !item.isConsumed && item.expirationStatus == .expired &&
            item.createdAt >= oneWeekAgo && item.createdAt <= now
        }
        
        let firstCount = firstWeek.count
        let secondCount = secondWeek.count
        
        guard firstCount > 0 || secondCount > 0 else {
            return ("Situazione stabile nelle ultime settimane", false)
        }
        
        if secondCount < firstCount {
            return ("Stai sprecando meno rispetto alla settimana scorsa 👍", true)
        } else if secondCount > firstCount {
            return ("Hai sprecato più prodotti rispetto alla settimana scorsa", true)
        } else {
            return ("Situazione stabile nelle ultime settimane", true)
        }
    }
    
    private func calculateAverageConsumptionDays(items: [FoodItem]) -> Int? {
        guard !items.isEmpty else { return nil }
        
        let calendar = Calendar.current
        var totalDays = 0
        var count = 0
        
        for item in items {
            let days = calendar.dateComponents([.day], from: item.createdAt, to: item.lastUpdated).day ?? 0
            if days > 0 {
                totalDays += days
                count += 1
            }
        }
        
        guard count > 0 else { return nil }
        return totalDays / count
    }
    
    private func calculateWasteByType(items: [FoodItem]) -> [FoodType: Double]? {
        let wastedItems = items.filter { !$0.isConsumed && $0.expirationStatus == .expired }
        guard !wastedItems.isEmpty else { return nil }
        
        var typeCounts: [FoodType: Int] = [:]
        var total = 0
        
        for item in wastedItems {
            if let type = item.foodType {
                typeCounts[type, default: 0] += 1
                total += 1
            }
        }
        
        guard total > 0 else { return nil }
        
        return typeCounts.mapValues { Double($0) / Double(total) * 100.0 }
    }
    
    private func generateWeeklyAdvice(
        monthlyStats: MonthlyStats,
        wasteByType: [FoodType: Double]?,
        avgDays: Int?
    ) -> String? {
        // Template consigli con supporto genere
        if monthlyStats.expired == 0 {
            let advice = GenderHelper.localizedString("stats.message.excellent", gender: userGender)
            // Fallback se la stringa non viene trovata
            return advice != "stats.message.excellent" ? advice : "Ottimo lavoro! Stai riducendo gli sprechi."
        }
        
        if let avgDays = avgDays, avgDays > 7 {
            return "Alcuni prodotti restano inutilizzati per molti giorni."
        }
        
        // Conta prodotti freschi aggiunti questo mese
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let freshCount = allItems.filter { $0.isFresh && $0.createdAt >= startOfMonth }.count
        
        if freshCount > 5 {
            return "Stai aggiungendo molti prodotti freschi: controlla quelli in scadenza."
        }
        
        let advice = GenderHelper.localizedString("stats.message.good", gender: userGender)
        // Fallback se la stringa non viene trovata
        return advice != "stats.message.good" ? advice : "Stai facendo bene! Continua così."
    }
    
    private func calculateTopProducts(items: [FoodItem], filterConsumed: Bool) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        
        for item in items {
            if filterConsumed && !item.isConsumed {
                continue
            }
            counts[item.name, default: 0] += 1
        }
        
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM"
        return f
    }()
    
    private func calculateWeeklyData(calendar: Calendar, now: Date) -> [WeeklyDataPoint]? {
        var weeklyPoints: [WeeklyDataPoint] = []
        for weekOffset in 0..<4 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }
            let weekItems = allItems.filter { item in
                item.createdAt >= weekStart && item.createdAt < weekEnd
            }
            let consumed = weekItems.filter { $0.isConsumed }.count
            let expired = weekItems.filter { !$0.isConsumed && $0.expirationStatus == .expired }.count
            let weekLabel = calendar.dateComponents([.weekOfYear, .year], from: weekStart)
            let weekString = "Sett. \(weekLabel.weekOfYear ?? 0)"
            let dateLabel = Self.shortDateFormatter.string(from: weekStart)
            weeklyPoints.append(WeeklyDataPoint(week: weekString, dateLabel: dateLabel, consumed: consumed, expired: expired))
        }
        return weeklyPoints.isEmpty ? nil : weeklyPoints.reversed()
    }
    
    // MARK: - Fridgy Insights Section
    private func fridgyInsightsSection(data: StatisticsData) -> some View {
        // Debug
        print("🔍 fridgyInsightsSection: isLoadingFridgy = \(isLoadingFridgy), fridgyInsights.count = \(fridgyInsights.count)")
        
        // Mostra skeleton loader se sta caricando
        if isLoadingFridgy {
            return AnyView(
                VStack(spacing: 12) {
                    FridgySkeletonLoader()
                        .frame(maxWidth: CGFloat.infinity, alignment: .leading)
                }
            )
        }
        
        // Mostra Fridgy se ha messaggi
        guard !fridgyInsights.isEmpty else {
            print("🔍 fridgyInsightsSection: fridgyInsights è vuoto, mostrando EmptyView")
            return AnyView(EmptyView())
        }
        
        print("🔍 fridgyInsightsSection: mostrando FridgyCard")
        return AnyView(
            VStack(spacing: 12) {
                ForEach(Array(fridgyInsights.enumerated()), id: \.offset) { index, insight in
                    FridgyCard(context: insight.context, message: insight.message)
                        .frame(maxWidth: CGFloat.infinity, alignment: .leading)
                }
            }
        )
    }
    
    private func loadFridgyInsights() {
        // La VIEW decide se mostrare Fridgy (controlla se è abilitato)
        guard IntelligenceManager.shared.isFridgyAvailable else {
            print("🔍 Fridgy: non disponibile (isFridgyAvailable = false)")
            fridgyInsights = []
            isLoadingFridgy = false
            return
        }
        
        guard let data = statsData else {
            print("🔍 Fridgy: statsData è nil")
            fridgyInsights = []
            isLoadingFridgy = false
            return
        }
        
        print("🔍 Fridgy: items.count = \(allItems.count), statsData presente")
        
        // La BUSINESS LOGIC decide il payload
        guard let payload = FridgyPayload.forStatistics(items: allItems, statistics: data) else {
            print("🔍 Fridgy: payload è nil (nessun suggerimento generato)")
            fridgyInsights = []
            isLoadingFridgy = false
            return
        }
        
        print("🔍 Fridgy: payload generato, context = \(payload.context), caricamento in corso...")
        
        // Mostra skeleton loader
        isLoadingFridgy = true
        
        // Il SERVIZIO genera il testo
        Task {
            do {
                let text = try await fridgyService.generateMessage(from: payload.promptContext)
                
                print("🔍 Fridgy: testo generato = '\(text)'")
                
                // Validazione: controlla che il testo sia valido
                let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sanitized.isEmpty && sanitized.count <= 100 {
                    await MainActor.run {
                        fridgyInsights = [(message: sanitized, context: payload.context)]
                        isLoadingFridgy = false
                        print("🔍 Fridgy: messaggio salvato, fridgyInsights.count = \(fridgyInsights.count)")
                    }
                } else {
                    print("🔍 Fridgy: testo non valido (vuoto o troppo lungo: \(sanitized.count) caratteri)")
                    await MainActor.run {
                        fridgyInsights = []
                        isLoadingFridgy = false
                    }
                }
            } catch {
                print("🔍 Fridgy: errore durante generazione - \(error.localizedDescription)")
                // Se Apple Intelligence non è disponibile o c'è un errore, Fridgy non mostra nulla
                await MainActor.run {
                    fridgyInsights = []
                    isLoadingFridgy = false
                }
            }
        }
    }
}

// MARK: - Category stat per "Per categoria"
struct CategoryStat {
    let category: FoodCategory
    let consumed: Int
    let total: Int
}

// MARK: - Data Models
struct StatisticsData {
    let wasteScore: Double
    let monthlyStats: MonthlyStats
    let recentTrendMessage: String
    let hasRecentTrend: Bool
    let averageConsumptionDays: Int?
    let wasteByType: [FoodType: Double]?
    let weeklyAdvice: String?
    let topAddedProducts: [(name: String, count: Int)]
    let topWastedProducts: [(name: String, count: Int)]
    let weeklyData: [WeeklyDataPoint]?
    let categoryStats: [CategoryStat]
    
    var hasCategoryStats: Bool {
        !categoryStats.isEmpty
    }
    
    var hasHabits: Bool {
        averageConsumptionDays != nil || (wasteByType != nil && monthlyStats.expired > 0)
    }
    
    var hasDetails: Bool {
        !topAddedProducts.isEmpty || !topWastedProducts.isEmpty
    }
    
    var hasChartData: Bool {
        weeklyData != nil && !weeklyData!.isEmpty
    }
    
    static var empty: StatisticsData {
        StatisticsData(
            wasteScore: 0.0,
            monthlyStats: MonthlyStats(consumed: 0, expired: 0, expiringSoon: 0),
            recentTrendMessage: "",
            hasRecentTrend: false,
            averageConsumptionDays: nil,
            wasteByType: nil,
            weeklyAdvice: nil,
            topAddedProducts: [],
            topWastedProducts: [],
            weeklyData: nil,
            categoryStats: []
        )
    }
}

struct WeeklyDataPoint: Identifiable {
    let id = UUID()
    let week: String
    /// Per il grafico: "1 feb", "8 feb"...
    let dateLabel: String
    let consumed: Int
    let expired: Int
}

struct MonthlyStats {
    let consumed: Int
    let expired: Int
    let expiringSoon: Int
}

// MARK: - Stat Row
private struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: FoodItem.self)
}
