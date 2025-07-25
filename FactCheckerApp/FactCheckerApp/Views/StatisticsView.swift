//
//  StatisticsView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI
import Charts

struct StatisticsView: View {
    @ObservedObject var coordinator: FactCheckCoordinator
    @State private var selectedTimeframe: StatisticsTimeframe = .week
    @State private var selectedMetric: MetricType = .accuracy
    
    enum MetricType: String, CaseIterable {
        case accuracy = "Accuracy"
        case volume = "Volume"
        case confidence = "Confidence"
        case sources = "Sources"
        
        var iconName: String {
            switch self {
            case .accuracy: return "target"
            case .volume: return "chart.bar"
            case .confidence: return "gauge.medium"
            case .sources: return "link"
            }
        }
    }
    
    var statistics: FactCheckStatistics {
        coordinator.getStatistics(for: selectedTimeframe)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Frame Selector
                    timeframeSelector
                    
                    // Overview Cards
                    overviewCards
                    
                    // Main Chart
                    mainChart
                    
                    // Truth Distribution
                    truthDistributionChart
                    
                    // Claim Types
                    claimTypesSection
                    
                    // Top Sources
                    topSourcesSection
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var timeframeSelector: some View {
        Picker("Timeframe", selection: $selectedTimeframe) {
            ForEach(StatisticsTimeframe.allCases, id: \.self) { timeframe in
                Text(timeframe.displayName).tag(timeframe)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
    
    private var overviewCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            OverviewCard(
                title: "Total Checks",
                value: "\(statistics.totalChecks)",
                icon: "checkmark.shield",
                color: .blue
            )
            
            OverviewCard(
                title: "Accuracy Rate",
                value: "\(statistics.accuracyRate * 100, specifier: "%.1f")%",
                icon: "target",
                color: .green
            )
            
            OverviewCard(
                title: "Avg Confidence",
                value: "\(statistics.averageConfidence * 100, specifier: "%.1f")%",
                icon: "gauge.medium",
                color: .orange
            )
            
            OverviewCard(
                title: "Verification Rate",
                value: "\(statistics.verificationRate * 100, specifier: "%.1f")%",
                icon: "checkmark.circle",
                color: .purple
            )
        }
    }
    
    private var mainChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trend Analysis")
                    .font(.headline)
                
                Spacer()
                
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(MetricType.allCases, id: \.self) { metric in
                        Label(metric.rawValue, systemImage: metric.iconName).tag(metric)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Chart would go here - using a placeholder for now
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Chart data for \(selectedMetric.rawValue.lowercased())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
        }
    }
    
    private var truthDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Truth Distribution")
                .font(.headline)
            
            VStack(spacing: 8) {
                TruthDistributionRow(
                    label: "True",
                    count: statistics.trueCount,
                    total: statistics.totalChecks,
                    color: .green
                )
                
                TruthDistributionRow(
                    label: "False",
                    count: statistics.falseCount,
                    total: statistics.totalChecks,
                    color: .red
                )
                
                TruthDistributionRow(
                    label: "Mixed",
                    count: statistics.mixedCount,
                    total: statistics.totalChecks,
                    color: .orange
                )
                
                TruthDistributionRow(
                    label: "Unknown",
                    count: statistics.unknownCount,
                    total: statistics.totalChecks,
                    color: .gray
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
    
    private var claimTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claim Types")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Array(statistics.claimTypeDistribution.keys), id: \.self) { claimType in
                    ClaimTypeCard(
                        claimType: claimType,
                        count: statistics.claimTypeDistribution[claimType] ?? 0
                    )
                }
            }
        }
    }
    
    private var topSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Sources")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(Array(statistics.topSources.enumerated()), id: \.offset) { index, source in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.domain)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(source.count) references")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(source.credibilityScore * 100, specifier: "%.0f")%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(source.credibilityScore > 0.8 ? .green : .orange)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct TruthDistributionRow: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text("(\(percentage * 100, specifier: "%.1f")%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: percentage)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
        }
    }
}

struct ClaimTypeCard: View {
    let claimType: ClaimType
    let count: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text(claimType.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Statistics Models

struct FactCheckStatistics {
    let totalChecks: Int
    let accuracyRate: Double
    let averageConfidence: Double
    let verificationRate: Double
    let trueCount: Int
    let falseCount: Int
    let mixedCount: Int
    let unknownCount: Int
    let claimTypeDistribution: [ClaimType: Int]
    let topSources: [SourceStatistic]
    let timeframe: StatisticsTimeframe
}

struct SourceStatistic {
    let domain: String
    let count: Int
    let credibilityScore: Double
}

enum StatisticsTimeframe: String, CaseIterable {
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .day: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .all: return "All Time"
        }
    }
}
