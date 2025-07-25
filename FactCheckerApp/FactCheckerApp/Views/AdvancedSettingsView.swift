//
//  AdvancedSettingsView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI

struct AdvancedSettingsView: View {
    @StateObject private var securityManager = SecurityManager()
    @StateObject private var privacyManager: PrivacyManager
    @StateObject private var settingsManager: SettingsManager
    
    @State private var showingDataUsageReport = false
    @State private var showingExportSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var isAuthenticating = false
    
    init(dataManager: DataManager, settingsManager: SettingsManager) {
        self._privacyManager = StateObject(wrappedValue: PrivacyManager(dataManager: dataManager))
        self._settingsManager = StateObject(wrappedValue: settingsManager)
    }
    
    var body: some View {
        NavigationView {
            List {
                securitySection
                privacySection
                dataManagementSection
                advancedSection
                aboutSection
            }
            .navigationTitle(L("advanced_settings"))
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingDataUsageReport) {
            DataUsageReportView(privacyManager: privacyManager)
        }
        .sheet(isPresented: $showingExportSheet) {
            DataExportView(privacyManager: privacyManager)
        }
        .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This will permanently delete all your fact-check history, speakers, and settings. This action cannot be undone.")
        }
    }
    
    private var securitySection: some View {
        Section {
            HStack {
                Label("Security", systemImage: "lock.shield")
                Spacer()
                Toggle("", isOn: .constant(securityManager.isSecurityEnabled))
                    .disabled(isAuthenticating)
                    .onChange(of: securityManager.isSecurityEnabled) { enabled in
                        toggleSecurity(enabled)
                    }
            }
            
            if securityManager.biometricType != .none {
                HStack {
                    Label(securityManager.biometricType.displayName, systemImage: biometricIcon)
                    Spacer()
                    Text("Available")
                        .foregroundColor(.secondary)
                }
            }
            
            if securityManager.isSecurityEnabled {
                Button("Change Security Settings") {
                    // Navigate to detailed security settings
                }
            }
        } header: {
            Text("Security")
        } footer: {
            Text("Enable biometric authentication to secure your data")
        }
    }
    
    private var privacySection: some View {
        Section {
            NavigationLink("Privacy Controls") {
                PrivacyControlsView(privacyManager: privacyManager)
            }
            
            HStack {
                Label("Data Retention", systemImage: "clock.arrow.circlepath")
                Spacer()
                Picker("", selection: $privacyManager.dataRetentionPeriod) {
                    ForEach(PrivacyManager.DataRetentionPeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Toggle(isOn: $privacyManager.localProcessingOnly) {
                Label("Local Processing Only", systemImage: "iphone")
            }
            
            Toggle(isOn: $privacyManager.allowAnalytics) {
                Label("Analytics", systemImage: "chart.bar")
            }
            
            Toggle(isOn: $privacyManager.shareAnonymousUsage) {
                Label("Anonymous Usage Data", systemImage: "person.crop.circle.badge.questionmark")
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Control how your data is processed and stored")
        }
    }
    
    private var dataManagementSection: some View {
        Section {
            Button("Data Usage Report") {
                showingDataUsageReport = true
            }
            
            Button("Export My Data") {
                showingExportSheet = true
            }
            
            Button("Clear Cache") {
                clearCache()
            }
            
            Button("Delete All Data", role: .destructive) {
                showingDeleteConfirmation = true
            }
        } header: {
            Text("Data Management")
        }
    }
    
    private var advancedSection: some View {
        Section {
            NavigationLink("Developer Options") {
                DeveloperOptionsView()
            }
            .disabled(!AppConfig.isDebug)
            
            HStack {
                Label("Background Processing", systemImage: "rectangle.stack.badge.play")
                Spacer()
                Toggle("", isOn: $settingsManager.enableBackgroundProcessing)
            }
            
            HStack {
                Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                Spacer()
                Toggle("", isOn: $settingsManager.enableHapticFeedback)
            }
            
            NavigationLink("Audio Settings") {
                AudioSettingsView(settingsManager: settingsManager)
            }
            
            NavigationLink("Network Settings") {
                NetworkSettingsView(settingsManager: settingsManager)
            }
        } header: {
            Text("Advanced")
        }
    }
    
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(AppConfig.appVersion)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text(AppConfig.buildNumber)
                    .foregroundColor(.secondary)
            }
            
            Button("Privacy Policy") {
                openURL(AppConfig.URLs.privacyPolicy)
            }
            
            Button("Terms of Service") {
                openURL(AppConfig.URLs.termsOfService)
            }
            
            Button("Support") {
                openURL(AppConfig.URLs.support)
            }
        } header: {
            Text("About")
        }
    }
    
    private var biometricIcon: String {
        switch securityManager.biometricType {
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        default:
            return "lock"
        }
    }
    
    private func toggleSecurity(_ enabled: Bool) {
        isAuthenticating = true
        
        Task {
            do {
                if enabled {
                    try await securityManager.enableSecurity()
                } else {
                    try await securityManager.disableSecurity()
                }
            } catch {
                // Handle error
                print("Security toggle error: \(error)")
            }
            
            DispatchQueue.main.async {
                isAuthenticating = false
            }
        }
    }
    
    private func clearCache() {
        NotificationCenter.default.post(name: .clearCacheData, object: nil)
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
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
