//
//  PrivacyControlsView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI

struct PrivacyControlsView: View {
    @ObservedObject var privacyManager: PrivacyManager
    @State private var showingDataDeletionAlert = false
    @State private var showingExportSheet = false
    
    var body: some View {
        List {
            dataCollectionSection
            dataRetentionSection
            dataProcessingSection
            dataRightsSection
        }
        .navigationTitle("Privacy Controls")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingExportSheet) {
            DataExportView(privacyManager: privacyManager)
        }
        .alert("Delete All Data", isPresented: $showingDataDeletionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This will permanently delete all your data. This action cannot be undone.")
        }
    }
    
    private var dataCollectionSection: some View {
        Section {
            Toggle(isOn: $privacyManager.allowAnalytics) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analytics")
                        .font(.body)
                    Text("Help improve the app by sharing usage analytics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Toggle(isOn: $privacyManager.allowCrashReporting) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Crash Reporting")
                        .font(.body)
                    Text("Automatically send crash reports to help fix bugs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Toggle(isOn: $privacyManager.shareAnonymousUsage) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Anonymous Usage Data")
                        .font(.body)
                    Text("Share anonymized usage patterns to improve fact-checking accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Data Collection")
        } footer: {
            Text("You can change these settings at any time. Disabling will not affect existing data.")
        }
    }
    
    private var dataRetentionSection: some View {
        Section {
            Picker("Data Retention Period", selection: $privacyManager.dataRetentionPeriod) {
                ForEach(PrivacyManager.DataRetentionPeriod.allCases, id: \.self) { period in
                    VStack(alignment: .leading) {
                        Text(period.displayName)
                        if period == .forever {
                            Text("Data is kept until manually deleted")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(period)
                }
            }
            .pickerStyle(NavigationLinkPickerStyle())
            
            Button("Clean Up Old Data Now") {
                privacyManager.cleanupOldData()
            }
            .foregroundColor(.orange)
        } header: {
            Text("Data Retention")
        } footer: {
            Text("Automatically delete fact-check history older than the selected period.")
        }
    }
    
    private var dataProcessingSection: some View {
        Section {
            Toggle(isOn: $privacyManager.localProcessingOnly) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Processing Only")
                        .font(.body)
                    Text("Process all data on-device without sending to servers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if privacyManager.localProcessingOnly {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Some features may be limited with local processing only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Data Processing")
        } footer: {
            Text("Local processing provides maximum privacy but may reduce accuracy for complex fact-checks.")
        }
    }
    
    private var dataRightsSection: some View {
        Section {
            Button("Export My Data") {
                showingExportSheet = true
            }
            
            Button("View Data Usage Report") {
                // Navigate to data usage report
            }
            
            Button("Request Data Correction") {
                openSupportForDataCorrection()
            }
            
            Button("Delete All My Data", role: .destructive) {
                showingDataDeletionAlert = true
            }
        } header: {
            Text("Your Data Rights")
        } footer: {
            Text("You have the right to access, correct, and delete your personal data.")
        }
    }
    
    private func deleteAllData() {
        Task {
            do {
                try await privacyManager.deleteAllPersonalData()
            } catch {
                print("Error deleting data: \(error)")
            }
        }
    }
    
    private func openSupportForDataCorrection() {
        guard let url = URL(string: "\(AppConfig.URLs.support)?subject=Data%20Correction%20Request") else { return }
        UIApplication.shared.open(url)
    }
}
