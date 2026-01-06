//
//  MacCostAnalyticsView.swift
//  SwiftSpeakMac
//
//  macOS version of Cost Analytics dashboard
//  Shows usage statistics and cost breakdown
//

import Charts
import SwiftUI
import SwiftSpeakCore

// MARK: - Cost Analytics View

struct MacCostAnalyticsView: View {
    @ObservedObject var settings: MacSettings

    @State private var selectedPeriod: AnalyticsPeriod = .month
    @State private var selectedCategory: AnalyticsCategory = .all

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period selector
                periodPicker

                // Category filter
                categoryPicker

                // Summary card
                summaryCard

                // Charts row
                HStack(spacing: 16) {
                    // Daily cost trend chart
                    if !dailyCostData.isEmpty {
                        dailyCostTrendChart
                    }

                    // Category pie chart
                    if categoryCostData.contains(where: { $0.cost > 0 }) {
                        categoryCostChart
                    }
                }
                .frame(height: 220)

                // Provider charts row
                HStack(spacing: 16) {
                    // Provider usage chart
                    if !providerUsageData.isEmpty {
                        providerUsageChart
                    }

                    // Provider cost chart
                    if !providerCostData.isEmpty {
                        providerCostChart
                    }
                }
                .frame(minHeight: CGFloat(max(providerUsageData.count, providerCostData.count)) * 44 + 60)

                // Category cards
                categoryBreakdown

                // Usage statistics
                usageStats
            }
            .padding(24)
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(AnalyticsPeriod.allCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 400)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(AnalyticsCategory.allCases) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: category.icon)
                            .font(.caption)
                        Text(category.displayName)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        selectedCategory == category
                            ? category.color.opacity(0.2)
                            : Color.clear,
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                selectedCategory == category
                                    ? category.color
                                    : Color.secondary.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedCategory == category ? category.color : .secondary)
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spend")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(filteredTotalCost.formattedCost)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Operations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(filteredRecords.count)")
                        .font(.title2.weight(.semibold))
                }
            }

            Divider()

            HStack {
                StatItem(
                    title: "Avg Cost",
                    value: filteredAverageCost.formattedCost
                )

                Spacer()

                StatItem(
                    title: "Total Words",
                    value: formatWordCount(totalWordCount)
                )

                Spacer()

                StatItem(
                    title: "Total Time",
                    value: formatDuration(totalDuration)
                )
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Daily Cost Trend Chart

    private var dailyCostTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cost Trend")
                    .font(.headline)
                Spacer()
                Text(selectedCategory.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedCategory.color.opacity(0.2), in: Capsule())
            }

            Chart(dailyCostData) { item in
                AreaMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Cost", item.cost)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [selectedCategory.color.opacity(0.3), selectedCategory.color.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Cost", item.cost)
                )
                .foregroundStyle(selectedCategory.color)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: selectedPeriod == .week ? .day : .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: selectedPeriod == .week ? .dateTime.weekday(.abbreviated) : .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let cost = value.as(Double.self) {
                            Text(cost.formattedCostCompact)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Category Cost Chart

    private var categoryCostChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost by Category")
                .font(.headline)

            Chart(categoryCostData) { item in
                BarMark(
                    x: .value("Cost", item.cost),
                    y: .value("Category", item.category)
                )
                .foregroundStyle(item.color.gradient)
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(item.cost.formattedCost)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            .frame(height: CGFloat(categoryCostData.count) * 32 + 20)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let cost = value.as(Double.self) {
                            Text(cost.formattedCostCompact)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }

            // Legend
            HStack(spacing: 12) {
                ForEach(categoryCostData) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        Text(item.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Provider Usage Chart

    private var providerUsageChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Provider Usage")
                    .font(.headline)
                Spacer()
                Text("Count")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(providerUsageData) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Provider", item.provider.displayName)
                )
                .foregroundStyle(item.color.gradient)
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading) {
                    Text("\(item.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Provider Cost Chart

    private var providerCostChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cost by Provider")
                    .font(.headline)
                Spacer()
                Text(selectedCategory.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedCategory.color.opacity(0.2), in: Capsule())
            }

            Chart(providerCostData) { item in
                BarMark(
                    x: .value("Cost", item.cost),
                    y: .value("Provider", item.provider.displayName)
                )
                .foregroundStyle(item.color.gradient)
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(item.cost.formattedCost)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let cost = value.as(Double.self) {
                            Text(cost.formattedCostCompact)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Summary")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                CategoryCard(
                    title: "Transcription",
                    cost: transcriptionCost,
                    icon: "waveform",
                    color: .blue
                )

                CategoryCard(
                    title: "Power Mode",
                    cost: powerModeCost,
                    icon: "bolt.fill",
                    color: .orange
                )

                CategoryCard(
                    title: "Translation",
                    cost: translationCost,
                    icon: "globe",
                    color: .green
                )

                CategoryCard(
                    title: "Prediction",
                    cost: predictionCost,
                    icon: "sparkles",
                    color: .pink
                )
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Usage Stats

    private var usageStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage Statistics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                UsageStatCard(
                    title: "Most Used Provider",
                    value: mostUsedProvider?.displayName ?? "—",
                    icon: "star.fill"
                )

                UsageStatCard(
                    title: "Longest Session",
                    value: formatDuration(longestDuration),
                    icon: "clock.fill"
                )

                UsageStatCard(
                    title: "This Week",
                    value: "\(thisWeekCount) ops",
                    icon: "calendar"
                )

                UsageStatCard(
                    title: "Today",
                    value: "\(todayCount) ops",
                    icon: "sun.max.fill"
                )
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Properties

    private var filteredRecords: [TranscriptionRecord] {
        let startDate = selectedPeriod.startDate
        return settings.transcriptionHistory.filter { $0.timestamp >= startDate }
    }

    private var filteredTotalCost: Double {
        switch selectedCategory {
        case .all:
            // Use costBreakdown.total if available, fallback to estimatedCost for legacy records
            return filteredRecords.map { $0.costBreakdown?.total ?? $0.estimatedCost ?? 0 }.reduce(0, +)
        case .transcription:
            return transcriptionCost
        case .powerMode:
            return powerModeCost
        case .translation:
            return translationCost
        case .prediction:
            return predictionCost
        }
    }

    private var filteredAverageCost: Double {
        guard !filteredRecords.isEmpty else { return 0 }
        return filteredTotalCost / Double(filteredRecords.count)
    }

    private var totalDuration: TimeInterval {
        filteredRecords.reduce(0) { $0 + $1.duration }
    }

    private var transcriptionCost: Double {
        filteredRecords.compactMap { $0.costBreakdown?.transcriptionCost }.reduce(0, +)
    }

    private var powerModeCost: Double {
        filteredRecords.compactMap { $0.costBreakdown?.formattingCost }.reduce(0, +)
    }

    private var translationCost: Double {
        filteredRecords.compactMap { $0.costBreakdown?.translationCost }.reduce(0, +)
    }

    private var predictionCost: Double {
        filteredRecords.compactMap { $0.costBreakdown?.predictionCost }.reduce(0, +)
    }

    private var totalWordCount: Int {
        filteredRecords.compactMap { $0.costBreakdown?.wordCount }.reduce(0, +)
    }

    // MARK: - Chart Data

    private var dailyCostData: [DailyCostItem] {
        let calendar = Calendar.current
        var dailyCosts: [Date: Double] = [:]

        for record in filteredRecords {
            let day = calendar.startOfDay(for: record.timestamp)
            let cost: Double
            switch selectedCategory {
            case .all:
                cost = record.estimatedCost ?? 0
            case .transcription:
                cost = record.costBreakdown?.transcriptionCost ?? 0
            case .powerMode:
                cost = record.costBreakdown?.formattingCost ?? 0
            case .translation:
                cost = record.costBreakdown?.translationCost ?? 0
            case .prediction:
                cost = record.costBreakdown?.predictionCost ?? 0
            }
            dailyCosts[day, default: 0] += cost
        }

        let startDate: Date
        if selectedPeriod == .all {
            if let earliestRecord = filteredRecords.min(by: { $0.timestamp < $1.timestamp }) {
                startDate = calendar.startOfDay(for: earliestRecord.timestamp)
            } else {
                return []
            }
        } else {
            startDate = selectedPeriod.startDate
        }

        let endDate = Date()
        var currentDate = startDate
        var result: [DailyCostItem] = []

        let maxDays = 365
        var dayCount = 0

        while currentDate <= endDate && dayCount < maxDays {
            let day = calendar.startOfDay(for: currentDate)
            result.append(DailyCostItem(date: day, cost: dailyCosts[day] ?? 0))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
            dayCount += 1
        }

        return result
    }

    private var providerUsageData: [ProviderUsageItem] {
        var counts: [AIProvider: Int] = [:]
        var wordCounts: [AIProvider: Int] = [:]

        for record in filteredRecords {
            counts[record.provider, default: 0] += 1
            let words = record.costBreakdown?.wordCount ?? record.text.split(separator: " ").count
            wordCounts[record.provider, default: 0] += words
        }

        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo, .mint]

        return counts.enumerated().map { index, item in
            ProviderUsageItem(
                provider: item.key,
                count: item.value,
                wordCount: wordCounts[item.key] ?? 0,
                color: colors[index % colors.count]
            )
        }.sorted { $0.count > $1.count }
    }

    private var providerCostData: [ProviderCostItem] {
        var costs: [AIProvider: Double] = [:]

        for record in filteredRecords {
            let cost: Double
            switch selectedCategory {
            case .all:
                cost = record.estimatedCost ?? 0
            case .transcription:
                cost = record.costBreakdown?.transcriptionCost ?? 0
            case .powerMode:
                cost = record.costBreakdown?.formattingCost ?? 0
            case .translation:
                cost = record.costBreakdown?.translationCost ?? 0
            case .prediction:
                cost = record.costBreakdown?.predictionCost ?? 0
            }
            if cost > 0 {
                costs[record.provider, default: 0] += cost
            }
        }

        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo, .mint]

        return costs.enumerated().compactMap { index, item in
            guard item.value > 0 else { return nil }
            let total = costs.values.reduce(0, +)
            return ProviderCostItem(
                provider: item.key,
                cost: item.value,
                percentage: total > 0 ? (item.value / total) * 100 : 0,
                color: colors[index % colors.count]
            )
        }.sorted { $0.cost > $1.cost }
    }

    private var categoryCostData: [CategoryCostItem] {
        [
            CategoryCostItem(category: "Transcription", cost: transcriptionCost, color: .blue),
            CategoryCostItem(category: "Power Mode", cost: powerModeCost, color: .orange),
            CategoryCostItem(category: "Translation", cost: translationCost, color: .purple),
            CategoryCostItem(category: "Prediction", cost: predictionCost, color: .pink)
        ].filter { $0.cost > 0 }
    }

    private var mostUsedProvider: AIProvider? {
        var counts: [AIProvider: Int] = [:]
        for record in filteredRecords {
            counts[record.provider, default: 0] += 1
        }
        return counts.max { $0.value < $1.value }?.key
    }

    private var longestDuration: TimeInterval {
        filteredRecords.map { $0.duration }.max() ?? 0
    }

    private var thisWeekCount: Int {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return settings.transcriptionHistory.filter { $0.timestamp >= weekStart }.count
    }

    private var todayCount: Int {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return settings.transcriptionHistory.filter { $0.timestamp >= todayStart }.count
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    private func formatWordCount(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)w"
        } else if count < 1_000_000 {
            return String(format: "%.1fK", Double(count) / 1000)
        } else {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
    }
}

// MARK: - Analytics Period

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .all: return "All Time"
        }
    }

    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.startOfDay(for: Date())
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .all:
            return Date.distantPast
        }
    }
}

// MARK: - Analytics Category

enum AnalyticsCategory: String, CaseIterable, Identifiable {
    case all
    case transcription
    case powerMode
    case translation
    case prediction

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .transcription: return "Transcription"
        case .powerMode: return "Power Mode"
        case .translation: return "Translation"
        case .prediction: return "Prediction"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .transcription: return "waveform"
        case .powerMode: return "bolt.fill"
        case .translation: return "globe"
        case .prediction: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .all: return .primary
        case .transcription: return .blue
        case .powerMode: return .orange
        case .translation: return .purple
        case .prediction: return .pink
        }
    }
}

// MARK: - Chart Data Models

struct DailyCostItem: Identifiable {
    let id = UUID()
    let date: Date
    let cost: Double
}

struct ProviderUsageItem: Identifiable {
    let id = UUID()
    let provider: AIProvider
    let count: Int
    let wordCount: Int
    let color: Color
}

struct ProviderCostItem: Identifiable {
    let id = UUID()
    let provider: AIProvider
    let cost: Double
    let percentage: Double
    let color: Color
}

struct CategoryCostItem: Identifiable {
    let id = UUID()
    let category: String
    let cost: Double
    let color: Color
}

// MARK: - Supporting Views

private struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.medium).monospacedDigit())
        }
    }
}

private struct CategoryCard: View {
    let title: String
    let cost: Double
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(cost.formattedCost)
                .font(.headline.monospacedDigit())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct UsageStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    MacCostAnalyticsView(settings: MacSettings.shared)
        .frame(width: 800, height: 700)
}
