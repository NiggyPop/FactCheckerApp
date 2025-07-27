//
//  DataUsageReportView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI
import Charts

struct DataUsageReportView: View {
    @ObservedObject var privacyManager: PrivacyManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var dataReport: DataUsageReport?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading data report...")
                } else if let report = dataReport {
                    reportContent(report)
                } else {
                    Text("Unable to load data report")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Data Usage Report")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadDataReport()
        }
    }
    
    private func reportContent(_ report: DataUsageReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    DataMetricCard(
                        title: "Total Fact Checks",
                        value: "\(report.totalFactChecks)",
                        icon: "checkmark.circle",
                        color: .blue
                    )
                    
                    DataMetricCard(
                        title: "Speakers",
                        value: "\(report.totalSpeakers)",
                        icon: "person.2",
                        color: .green
                    )
                    
                    DataMetricCard(
                        title: "Storage Used",
                        value: report.formattedStorageSize,
                        icon: "internaldrive",
                        color: .orange
                    )
                    
                    DataMetricCard(
                        title: "Retention Period",
                        value: report.retentionPeriod.displayName,
                        icon: "clock.arrow.circlepath",
                        color: .purple
                    )
                }
                
                // Timeline Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timeline")
                        .font(.headline)
                    
                    if let oldestRecord = report.oldestRecord {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text("Oldest Record:")
                            Spacer()
                            Text(oldestRecord, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let lastCleanup = report.lastCleanup {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.secondary)
                            Text("Last Cleanup:")
                            Spacer()
                            Text(lastCleanup, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Privacy Settings Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy Settings")
                        .font(.headline)
                    
                    PrivacySettingRow(
                        title: "Analytics",
                        isEnabled: privacyManager.allowAnalytics,
                        icon: "chart.bar"
                    )
                    
                    PrivacySettingRow(
                        title: "Crash Reporting",
                        isEnabled: privacyManager.allowCrashReporting,
                        icon: "exclamationmark.triangle"
                    )
                    
                    PrivacySettingRow(
                        title: "Anonymous Usage",
                        isEnabled: privacyManager.shareAnonymousUsage,
                        icon: "person.crop.circle.badge.questionmark"
                    )
                    
                    PrivacySettingRow(
                        title: "Local Processing Only",
                        isEnabled: privacyManager.localProcessingOnly,
                        icon: "iphone"
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Actions
                VStack(spacing: 12) {
                    Button("Export Data Report") {
                        exportReport(report)
                    }
                    
                    Button("Clean Up Old Data") {
                        privacyManager.cleanupOldData()
                    }
                    .foregroundColor(.orange)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func loadDataReport() {
        DispatchQueue.global(qos: .userInitiated).async {
            let report = privacyManager.getDataUsageReport()
            
            DispatchQueue.main.async {
                self.dataReport = report
                self.isLoading = false
            }
        }
    }
    
    private func exportReport(_ report: DataUsageReport) {
        // Implementation for exporting the report
        let reportData = generateReportData(report)
        shareReport(reportData)
    }
    
    private func generateReportData(_ report: DataUsageReport) -> Data {
        let reportText = """
        FactCheck Pro - Data Usage Report
        Generated: \(Date())
        
        Summary:
        - Total Fact Checks: \(report.totalFactChecks)
        - Total Speakers: \(report.totalSpeakers)
        - Storage Used: \(report.formattedStorageSize)
        - Retention Period: \(report.retentionPeriod.displayName)
        
        Privacy Settings:
        - Analytics: \(privacyManager.allowAnalytics ? "Enabled" : "Disabled")
        - Crash Reporting: \(privacyManager.allowCrashReporting ? "Enabled" : "Disabled")
        - Anonymous Usage: \(privacyManager.shareAnonymousUsage ? "Enabled" : "Disabled")
        - Local Processing Only: \(privacyManager.localProcessingOnly ? "Enabled" : "Disabled")
        """
        
        return reportText.data(using: .utf8) ?? Data()
    }
    
    private func shareReport(_ data: Data) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("data_usage_report.txt")
        
        do {
            try data.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityVC, animated: true)
            }
        } catch {
            print("Error sharing report: \(error)")
        }
    }
}

struct DataMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct PrivacySettingRow: View {
    let title: String
    let isEnabled: Bool
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
            
            Spacer()
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isEnabled ? .green : .red)
        }
    }
}
