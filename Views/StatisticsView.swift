import SwiftUI
import SwiftData
import Charts

/// Vista delle statistiche - UI/UX basata su screen (Waste Score, grafico, per categoria, dettagli)
struct StatisticsView: View {
    @Query(sort: \FoodItem.createdAt, order: .reverse) private var allItems: [FoodItem]
    @Query private var userProfiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var themeManager = ThemeManager.shared
    @State private var statsData: StatisticsData?
    
    private var userGender: GenderHelper.Gender {
        GenderHelper.getGender(from: userProfiles.first)
    }
    
    private var primaryColor: Color {
        themeManager.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : themeManager.primaryColor
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let data = statsData {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Card informativa introduttiva (Fridgy in base al Waste Score + testo)
                            StatisticsIntroCard()
                            
                            // Card di ingresso alle viste dettaglio (solo titoli)
                            VStack(spacing: 12) {
                                NavigationLink {
                                    TrophiesView()
                                } label: {
                                    StatEntryCard(icon: "trophy.fill", title: "trophy.title".localized, iconColor: primaryColor)
                                }
                                .buttonStyle(.plain)
                                
                                NavigationLink {
                                    WasteScoreDetailView(data: data, primaryColor: primaryColor, primaryColorDark: themeManager.primaryColorDark)
                                } label: {
                                    StatEntryCard(icon: "chart.pie.fill", title: "stats.waste_score".localized, iconColor: .red)
                                }
                                .buttonStyle(.plain)
                                
                                if data.hasChartData {
                                    NavigationLink {
                                        UsedVsWastedDetailView(data: data, primaryColor: primaryColor)
                                    } label: {
                                        StatEntryCard(icon: "chart.bar.fill", title: "stats.food_waste".localized, iconColor: .blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if data.hasCategoryStats {
                                    NavigationLink {
                                        CategoryDetailView(data: data, primaryColor: primaryColor)
                                    } label: {
                                        StatEntryCard(icon: "square.grid.2x2.fill", title: "stats.categories".localized, iconColor: .green)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if data.averageConsumptionDays != nil {
                                    NavigationLink {
                                        AverageDaysDetailView(data: data, primaryColor: primaryColor)
                                    } label: {
                                        StatEntryCard(icon: "clock.badge.checkmark", title: "stats.how_long_products".localized, iconColor: Color(red: 0.2, green: 0.6, blue: 0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if data.costStatsWeek != nil || data.costStatsMonth != nil || data.costStatsYear != nil {
                                    NavigationLink {
                                        CostDetailView(data: data, primaryColor: primaryColor)
                                    } label: {
                                        StatEntryCard(icon: "eurosign.circle.fill", title: "stats.costs.title".localized, iconColor: .orange)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                NavigationLink {
                                    PriceOverviewView(data: data, primaryColor: primaryColor)
                                } label: {
                                    StatEntryCard(icon: "chart.line.uptrend.xyaxis", title: "stats.prices.title".localized, iconColor: .orange)
                                }
                                .buttonStyle(.plain)
                                
                                NavigationLink {
                                    DetailsDetailView(data: data, primaryColor: primaryColor)
                                } label: {
                                    StatEntryCard(icon: "list.bullet.rectangle", title: "stats.in_detail".localized, iconColor: Color(red: 0.5, green: 0.4, blue: 0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, AppTheme.spacingBelowLargeTitle)
                        .padding(.bottom, AppTheme.spacingBelowLargeTitle)
                    }
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistiche")
            .navigationBarTitleDisplayMode(.large)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ConsumedHistoryView()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                    }
                }
            }
            .tint(primaryColor)
            .onAppear {
                calculateStatistics()
                TrophyService.shared.checkTrophies(items: allItems)
            }
            .onChange(of: allItems.count) { _, _ in
                calculateStatistics()
                TrophyService.shared.checkTrophies(items: allItems)
            }
        }
    }
    
    // MARK: - Card informativa introduttiva (Fridgy fisso + testo)
    private struct StatisticsIntroCard: View {
        var body: some View {
            VStack(spacing: 14) {
                Image("FridgyStatisticsIntro")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 160, maxHeight: 160)
                VStack(spacing: 6) {
                    Text("stats.intro.title".localized)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    Text("stats.intro.subtitle".localized)
                        .font(.system(size: 14))
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
    }
    
    // MARK: - Card di ingresso (solo icona + titolo, senza descrizione)
    private struct StatEntryCard: View {
        let icon: String
        let title: String
        let iconColor: Color
        
        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
                    .frame(width: 48, height: 48)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("stats.empty.title".localized)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            Text("stats.empty.subtitle".localized)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Statistics Calculation
    private func calculateStatistics() {
        let calendar = Calendar.current
        let now = Date()
        
        let periodStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        
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
        let (costWeek, costMonth, costYear) = calculateCostStats(calendar: calendar, now: now)
        
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
            categoryStats: categoryStats,
            costStatsWeek: costWeek,
            costStatsMonth: costMonth,
            costStatsYear: costYear
        )
    }
    
    private func calculateCostStats(calendar: Calendar, now: Date) -> (week: CostStats?, month: CostStats?, year: CostStats?) {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? now
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
        let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) ?? now
        
        func spent(in start: Date, end: Date) -> Double {
            allItems.filter { item in
                guard let p = item.price, p > 0 else { return false }
                return item.createdAt >= start && item.createdAt < end
            }.reduce(0) { $0 + ($1.price ?? 0) }
        }
        func wasted(in start: Date, end: Date) -> Double {
            allItems.filter { item in
                guard !item.isConsumed, item.expirationStatus == .expired, let p = item.price, p > 0 else { return false }
                let exp = item.effectiveExpirationDate
                return exp >= start && exp < end
            }.reduce(0) { $0 + ($1.price ?? 0) }
        }
        func saved(in start: Date, end: Date) -> Double {
            allItems.filter { item in
                guard item.isConsumed, let consumed = item.consumedDate, let p = item.price, p > 0 else { return false }
                return consumed >= start && consumed < end
            }.reduce(0) { $0 + ($1.price ?? 0) }
        }
        
        let hasAnyPrice = allItems.contains { ($0.price ?? 0) > 0 }
        guard hasAnyPrice else { return (nil, nil, nil) }
        
        let week = CostStats(spent: spent(in: startOfWeek, end: endOfWeek), wasted: wasted(in: startOfWeek, end: endOfWeek), saved: saved(in: startOfWeek, end: endOfWeek))
        let month = CostStats(spent: spent(in: startOfMonth, end: endOfMonth), wasted: wasted(in: startOfMonth, end: endOfMonth), saved: saved(in: startOfMonth, end: endOfMonth))
        let year = CostStats(spent: spent(in: startOfYear, end: endOfYear), wasted: wasted(in: startOfYear, end: endOfYear), saved: saved(in: startOfYear, end: endOfYear))
        return (week, month, year)
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
}

// MARK: - Card "In breve" (testo introduttivo umano, senza tono fiscale)
private struct StatInBriefCard: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 22))
                .foregroundStyle(.secondary.opacity(0.9))
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                Text("stats.section.in_brief".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Card "Un'idea per te" (consiglio / Come migliorare)
private struct StatTipCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 22))
                .foregroundStyle(.orange.opacity(0.9))
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 8) {
                Text("stats.section.tip".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Dettaglio Waste Score
private struct WasteScoreDetailView: View {
    let data: StatisticsData
    let primaryColor: Color
    let primaryColorDark: Color
    @State private var animatedWasteScore: Double = 0
    @State private var improveTip: String?
    @State private var isLoadingImprove = false
    private let fridgyService = FridgyServiceImpl.shared
    
    private func emoji(percentage: Double) -> String {
        if percentage >= 1.0 { return "🎉" }
        if percentage >= 0.8 { return "👍" }
        return "⚠️"
    }
    private func title(percentage: Double) -> String {
        if percentage >= 1.0 { return "Perfetto!" }
        if percentage >= 0.8 { return "Quasi perfetto" }
        return "Attenzione agli sprechi"
    }
    private func subtitle(wasted: Int) -> String {
        if wasted == 0 { return "Nessun prodotto scaduto questo mese" }
        return "\(wasted) \(wasted == 1 ? "prodotto scaduto" : "prodotti scaduti") questo mese"
    }
    
    private func ctaLabel(percentage: Double) -> String {
        if percentage >= 1.0 { return "Continua così" }
        if percentage >= 0.8 { return "Continua così" }
        return "Puoi migliorare"
    }
    
    private func ctaEmoji(percentage: Double) -> String {
        if percentage >= 0.8 { return "💪" }
        return "📈"
    }
    
    private var wasteScoreSentiment: (pillColor: Color, glowColor: Color) {
        if data.wasteScore >= 0.8 { return (.green, .green) }
        if data.wasteScore >= 0.5 { return (Color(red: 0.95, green: 0.7, blue: 0.2), Color.orange) }
        return (.red.opacity(0.9), .red)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Contenuto: Fridgy + percentuale in pill con glow
                VStack(alignment: .leading, spacing: 8) {
                    Text("stats.section.data".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    VStack(spacing: 16) {
                        Text("stats.waste_score".localized)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Image(FridgyEmotion.forWasteScore(data.wasteScore).imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 140, maxHeight: 140)
                        Text(title(percentage: data.wasteScore))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        Text(subtitle(wasted: data.monthlyStats.expired)).font(.system(size: 14)).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button { } label: {
                            HStack(spacing: 6) {
                                Text(ctaLabel(percentage: data.wasteScore))
                                Text(ctaEmoji(percentage: data.wasteScore))
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(primaryColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("stats.period".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 16) {
                            Label("\(data.monthlyStats.consumed) " + "stats.consumed_label".localized, systemImage: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.green)
                            Label("\(data.monthlyStats.expired) " + "stats.expired_label".localized, systemImage: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
                
                StatInBriefCard(text: "stats.waste_score.description".localized)
                
                StatTipCard {
                    if isLoadingImprove {
                        FridgySkeletonLoader()
                    } else if let tip = improveTip {
                        Text(tip)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    } else if !IntelligenceManager.shared.isFridgyAvailable {
                        Text("stats.fridgy_off_tip".localized)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("stats.waste_score".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) { animatedWasteScore = data.wasteScore }
            loadImproveTip()
        }
    }
    
    private func loadImproveTip() {
        guard IntelligenceManager.shared.isFridgyAvailable,
              let payload = FridgyPayload.forWasteScoreImprovement(statistics: data) else { return }
        isLoadingImprove = true
        Task {
            do {
                let text = try await fridgyService.generateMessage(from: payload.promptContext)
                let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    improveTip = sanitized.isEmpty ? nil : String(sanitized.prefix(120))
                    isLoadingImprove = false
                }
            } catch {
                await MainActor.run {
                    improveTip = nil
                    isLoadingImprove = false
                }
            }
        }
    }
}

// MARK: - Dettaglio Cibo usato vs sprecato
private struct UsedVsWastedDetailView: View {
    let data: StatisticsData
    let primaryColor: Color
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StatInBriefCard(text: "stats.used_vs_wasted.description".localized)
                
                // Contenuto
                VStack(alignment: .leading, spacing: 8) {
                    Text("stats.section.data".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("stats.food_waste".localized)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Text("stats.chart.consumed_vs_expired".localized)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        if let weeklyData = data.weeklyData {
                            Text("stats.chart.last_4_weeks".localized)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Chart(weeklyData) { point in
                                BarMark(x: .value("Data", point.dateLabel), y: .value("Consumati", point.consumed))
                                    .foregroundStyle(primaryColor)
                                BarMark(x: .value("Data", point.dateLabel), y: .value("Scaduti", point.expired))
                                    .foregroundStyle(.red)
                            }
                            .chartXAxis { AxisMarks(values: .automatic) { _ in AxisValueLabel().font(.system(size: 11)) } }
                            .chartYAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 11)) } }
                            .frame(height: 220)
                            HStack(spacing: 20) {
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 4).fill(primaryColor).frame(width: 12, height: 12)
                                    Text("stats.chart.consumed".localized).font(.system(size: 13)).foregroundColor(.secondary)
                                }
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.red).frame(width: 12, height: 12)
                                    Text("stats.chart.expired".localized).font(.system(size: 13)).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("stats.food_waste".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dettaglio Categorie
private struct CategoryDetailView: View {
    let data: StatisticsData
    let primaryColor: Color
    
    private var totalItems: Int {
        data.categoryStats.reduce(0) { $0 + $1.total }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StatInBriefCard(text: "stats.by_category.description".localized)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("stats.section.data".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("stats.categories".localized)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Text("\(totalItems) prodotti nel periodo · Consumati vs totali per luogo")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        ForEach(data.categoryStats, id: \.category) { stat in
                            HStack(spacing: 12) {
                                Image(systemName: stat.category.iconFill)
                                    .font(.system(size: 22))
                                    .foregroundColor(AppTheme.color(for: stat.category))
                                    .frame(width: 32)
                                Text(stat.category.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                                Spacer(minLength: 8)
                                if stat.total > 0 && stat.consumed == stat.total {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 16))
                                }
                                Text("\(stat.consumed)/\(stat.total)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("stats.categories".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dettaglio Quanto tieni i prodotti
private struct AverageDaysDetailView: View {
    let data: StatisticsData
    let primaryColor: Color
    
    private static let teal = Color(red: 0.2, green: 0.6, blue: 0.7)
    
    var body: some View {
        Group {
            if let avgDays = data.averageConsumptionDays {
                ScrollView {
                    VStack(spacing: 24) {
                        // Card hero: numero grande centrato
                        VStack(spacing: 20) {
                            Text("stats.how_long.avg_title".localized)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Image(systemName: "clock.badge.checkmark")
                                .font(.system(size: 40))
                                .foregroundStyle(Self.teal.opacity(0.4))
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(avgDays)")
                                    .font(.system(size: 72, weight: .bold))
                                    .foregroundColor(Self.teal)
                                Text(avgDays == 1 ? "stats.how_long.day".localized : "stats.how_long.days".localized)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            Text("stats.how_long.footer".localized)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .padding(.horizontal, 24)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                    }
                    .padding(20)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("stats.how_long_products".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dettaglio Andamento prezzi (panoramica, andamento nel tempo, per prodotto)
private struct PriceOverviewView: View {
    let data: StatisticsData
    let primaryColor: Color
    @Query(sort: \FoodItem.createdAt, order: .reverse) private var allItems: [FoodItem]
    
    private var itemsWithPrice: [FoodItem] {
        allItems.filter { ($0.price ?? 0) > 0 }
    }
    
    /// Spesa per mese (ultimi 12 mesi): mese → somma prezzi degli item aggiunti in quel mese
    private var spentByMonth: [(month: Date, total: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(Date, Double)] = []
        for i in (0..<12).reversed() {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }
            let total = allItems
                .filter { ($0.price ?? 0) > 0 && $0.createdAt >= monthStart && $0.createdAt < monthEnd }
                .reduce(0) { $0 + ($1.price ?? 0) }
            result.append((monthStart, total))
        }
        return result
    }
    
    private var totalSpentAllTime: Double {
        itemsWithPrice.reduce(0) { $0 + ($1.price ?? 0) }
    }
    
    private var averagePrice: Double {
        guard !itemsWithPrice.isEmpty else { return 0 }
        return totalSpentAllTime / Double(itemsWithPrice.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StatInBriefCard(text: "stats.prices.description".localized)
                
                if itemsWithPrice.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("stats.prices.empty_title".localized)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("stats.prices.empty_why".localized)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
                
                // Panoramica
                VStack(alignment: .leading, spacing: 12) {
                    Text("stats.prices.overview".localized)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    VStack(spacing: 0) {
                        row(title: "stats.prices.total_tracked".localized, value: totalSpentAllTime)
                        row(title: "stats.prices.products_with_price".localized, value: nil, count: itemsWithPrice.count)
                        if !itemsWithPrice.isEmpty {
                            row(title: "stats.prices.average".localized, value: averagePrice)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
                
                // Andamento per mese
                if !itemsWithPrice.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("stats.prices.trend".localized)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        VStack(spacing: 8) {
                            ForEach(Array(spentByMonth.enumerated()), id: \.offset) { _, pair in
                                HStack {
                                    Text(monthLabel(pair.month))
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(pair.total.formatted(.currency(code: "EUR")))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(primaryColor)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Per prodotto
                VStack(alignment: .leading, spacing: 12) {
                    Text("stats.prices.by_product".localized)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    if itemsWithPrice.isEmpty {
                        Text("stats.prices.no_prices".localized)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(itemsWithPrice.prefix(50)) { item in
                                HStack(spacing: 12) {
                                    Image(systemName: item.category.iconFill)
                                        .font(.system(size: 18))
                                        .foregroundColor(AppTheme.color(for: item.category))
                                        .frame(width: 36, height: 36)
                                        .background(AppTheme.color(for: item.category).opacity(0.15))
                                        .clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(item.category.rawValue)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text((item.price ?? 0).formatted(.currency(code: "EUR")))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(primaryColor)
                                }
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("stats.prices.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func row(title: String, value: Double?, count: Int? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer()
            if let value = value {
                Text(value.formatted(.currency(code: "EUR")))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(primaryColor)
            } else if let count = count {
                Text("\(count)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(primaryColor)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale.current
        return f.string(from: date)
    }
}

// MARK: - Dettaglio Costi e risparmi
private struct CostDetailView: View {
    let data: StatisticsData
    let primaryColor: Color
    
    private func row(title: String, value: Double, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            Spacer()
            Text(value.formatted(.currency(code: "EUR")))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.vertical, 8)
    }
    
    private func periodCard(title: String, stats: CostStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            row(title: "stats.costs.spent".localized, value: stats.spent, color: primaryColor)
            row(title: "stats.costs.wasted".localized, value: stats.wasted, color: .red)
            row(title: "stats.costs.saved".localized, value: stats.saved, color: .green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StatInBriefCard(text: "stats.costs.description".localized)
                
                if let week = data.costStatsWeek {
                    periodCard(title: "stats.costs.this_week".localized, stats: week)
                }
                if let month = data.costStatsMonth {
                    periodCard(title: "stats.costs.this_month".localized, stats: month)
                }
                if let year = data.costStatsYear {
                    periodCard(title: "stats.costs.this_year".localized, stats: year)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("stats.costs.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dettaglio Nel dettaglio (prodotti più aggiunti)
private struct DetailsDetailView: View {
    let data: StatisticsData
    let primaryColor: Color
    
    private var totalAdded: Int {
        data.topAddedProducts.reduce(0) { $0 + $1.count }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StatInBriefCard(text: "stats.details.description".localized)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("stats.section.data".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("stats.details.most_added".localized)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Text("\(data.topAddedProducts.count) prodotti · \(totalAdded) inserimenti totali")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        if data.topAddedProducts.isEmpty {
                            Text("stats.details.detail_later".localized)
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(data.topAddedProducts.prefix(10).enumerated()), id: \.element.name) { index, item in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color(red: 0.5, green: 0.4, blue: 0.8))
                                        .clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                        Text(String(format: "stats.details.added_times".localized, item.count))
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    
                    if !data.topWastedProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("stats.details.most_wasted".localized)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            Text("\(data.topWastedProducts.count) prodotti scaduti senza consumo")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            ForEach(Array(data.topWastedProducts.prefix(5).enumerated()), id: \.element.name) { index, item in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                    Text(item.name)
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("stats.in_detail".localized)
        .navigationBarTitleDisplayMode(.inline)
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
    let costStatsWeek: CostStats?
    let costStatsMonth: CostStats?
    let costStatsYear: CostStats?
    
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
            categoryStats: [],
            costStatsWeek: nil,
            costStatsMonth: nil,
            costStatsYear: nil
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

/// Statistiche costi per un periodo: spesa (acquistato), sprecato (scaduto), risparmiato (consumato prima di scadere)
struct CostStats {
    let spent: Double
    let wasted: Double
    let saved: Double
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
