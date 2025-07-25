//
//  SettingsView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var showingAbout = false
    @State private var showingPrivacyPolicy = false
    @State private var showingExportData = false
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // General Settings
                generalSection
                
                // Fact Checking Settings
                factCheckingSection
                
                // Audio Settings
                audioSection
                
                // Privacy Settings
                privacySection
                
                // Data Management
                dataManagementSection
                
                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .alert("Reset All Data", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                settingsManager.resetAllData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all fact-check history, speakers, and settings. This action cannot be undone.")
        }
    }
    
    private var generalSection: some View {
        Section("General") {
            HStack {
                Label("Theme", systemImage: "paintbrush")
                Spacer()
                Picker("Theme", selection: $settingsManager.appTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Toggle(isOn: $settingsManager.enableHapticFeedback) {
                Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
            }
            
            Toggle(isOn: $settingsManager.enableNotifications) {
                Label("Notifications", systemImage: "bell")
            }
        }
    }
    
    private var factCheckingSection: some View {
        Section("Fact Checking") {
            Toggle(isOn: $settingsManager.enableRealTimeFactChecking) {
                Label("Real-time Fact Checking", systemImage: "checkmark.shield")
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Confidence Threshold", systemImage: "gauge.medium")
                    Spacer()
                    Text("\(settingsManager.confidenceThreshold * 100, specifier: "%.0f")%")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $settingsManager.confidenceThreshold, in: 0.1...1.0, step: 0.1)
                    .accentColor(.blue)
                
                Text("Only show results above this confidence level")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle(isOn: $settingsManager.enableSourceVerification) {
                Label("Source Verification", systemImage: "link.badge.plus")
            }
            
            HStack {
                Label("Max Sources per Check", systemImage: "number.circle")
                Spacer()
                Stepper("\(settingsManager.maxSourcesPerCheck)", 
                       value: $settingsManager.maxSourcesPerCheck, 
                       in: 1...10)
            }
        }
    }
    
    private var audioSection: some View {
        Section("Audio & Speech") {
            Toggle(isOn: $settingsManager.enableSpeakerIdentification) {
                Label("Speaker Identification", systemImage: "person.wave.2")
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Audio Sensitivity", systemImage: "waveform")
                    Spacer()
                    Text(sensitivityLabel)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $settingsManager.audioSensitivity, in: 0.1...1.0, step: 0.1)
                    .accentColor(.blue)
            }
            
            HStack {
                Label("Language", systemImage: "globe")
                Spacer()
                Picker("Language", selection: $settingsManager.speechRecognitionLanguage) {
                    ForEach(SupportedLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Toggle(isOn: $settingsManager.enableContinuousListening) {
                Label("Continuous Listening", systemImage: "ear")
            }
        }
    }
    
    private var privacySection: some View {
        Section("Privacy & Security") {
            Toggle(isOn: $settingsManager.enableDataCollection) {
                Label("Anonymous Analytics", systemImage: "chart.bar.doc.horizontal")
            }
            
            Toggle(isOn: $settingsManager.storeAudioLocally) {
                Label("Store Audio Locally", systemImage: "internaldrive")
            }
            
            Button(action: { showingPrivacyPolicy = true }) {
                Label("Privacy Policy", systemImage: "hand.raised")
                    .foregroundColor(.primary)
            }
            
            HStack {
                Label("Data Retention", systemImage: "calendar.badge.clock")
                Spacer()
                Picker("Retention", selection: $settingsManager.dataRetentionPeriod) {
                    ForEach(DataRetentionPeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
    
    private var dataManagementSection: some View {
        Section("Data Management") {
            HStack {
                Label("Storage Used", systemImage: "internaldrive")
                Spacer()
                Text(settingsManager.storageUsed)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { showingExportData = true }) {
                Label("Export Data", systemImage: "square.and.arrow.up")
                    .foregroundColor(.blue)
            }
            
            Button(action: settingsManager.clearCache) {
                Label("Clear Cache", systemImage: "trash")
                    .foregroundColor(.orange)
            }
            
            Button(action: { showingResetAlert = true }) {
                Label("Reset All Data", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            Button(action: { showingAbout = true }) {
                Label("About FactCheck Pro", systemImage: "info.circle")
                    .foregroundColor(.primary)
            }
            
            HStack {
                Label("Version", systemImage: "number.circle")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }
            
            Button(action: openAppStore) {
                Label("Rate App", systemImage: "star")
                    .foregroundColor(.primary)
            }
            
            Button(action: contactSupport) {
                Label("Contact Support", systemImage: "envelope")
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var sensitivityLabel: String {
        switch settingsManager.audioSensitivity {
        case 0.1...0.3: return "Low"
        case 0.4...0.6: return "Medium"
        case 0.7...1.0: return "High"
        default: return "Medium"
        }
    }
    
    private func openAppStore() {
        // Open App Store for rating
        if let url = URL(string: "https://apps.apple.com/app/id123456789") {
            UIApplication.shared.open(url)
        }
    }
    
    private func contactSupport() {
        // Open email client
        if let url = URL(string: "mailto:support@factcheckpro.com") {
            UIApplication.shared.open(url)
        }
    }
}

struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon and Title
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("FactCheck Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Real-time fact checking with AI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.headline)
                        
                        FeatureRow(icon: "mic.fill", title: "Real-time Speech Recognition", description: "Automatically transcribe and analyze spoken statements")
                        
                        FeatureRow(icon: "person.2.fill", title: "Speaker Identification", description: "Identify and track different speakers")
                        
                        FeatureRow(icon: "checkmark.shield.fill", title: "AI-Powered Fact Checking", description: "Advanced algorithms verify claims against reliable sources")
                        
                        FeatureRow(icon: "chart.bar.fill", title: "Detailed Analytics", description: "Track accuracy rates and fact-checking statistics")
                        
                        FeatureRow(icon: "link", title: "Source Verification", description: "Cross-reference multiple credible sources")
                    }
                    
                    // Credits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Credits")
                            .font(.headline)
                        
                        Text("Developed with ❤️ using SwiftUI and advanced machine learning technologies.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Special thanks to the open-source community and fact-checking organizations worldwide.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Version Info
                    VStack(spacing: 8) {
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Last updated: \(Date(), formatter: DateFormatter.mediumDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    privacyContent
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            PrivacySection(
                title: "Data Collection",
                content: "We collect minimal data necessary for app functionality. Audio data is processed locally when possible and is not stored permanently unless explicitly enabled by the user."
            )
            
            PrivacySection(
                title: "Speech Recognition",
                content: "Speech recognition may use Apple's Speech framework or other services. Audio data sent for processing is not stored by these services beyond the processing period."
            )
            
            PrivacySection(
                title: "Fact Checking",
                content: "Statements are sent to fact-checking services for verification. No personal information is included with these requests."
            )
            
            PrivacySection(
                title: "Analytics",
                content: "Anonymous usage analytics help improve the app. You can disable this in Settings. No personally identifiable information is collected."
            )
            
            PrivacySection(
                title: "Data Storage",
                content: "All personal data is stored locally on your device. You can export or delete your data at any time through the Settings."
            )
            
            PrivacySection(
                title: "Contact",
                content: "For privacy questions or concerns, contact us at privacy@factcheckpro.com"
            )
        }
    }
}

struct PrivacySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Settings Enums

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum SupportedLanguage: String, CaseIterable {
    case english = "en-US"
    case spanish = "es-ES"
    case french = "fr-FR"
    case german = "de-DE"
    case italian = "it-IT"
    case portuguese = "pt-BR"
    case chinese = "zh-CN"
    case japanese = "ja-JP"
    case russian = "ru-RU"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .russian: return "Russian"
        }
    }
}

enum DataRetentionPeriod: String, CaseIterable {
    case oneWeek = "1week"
    case oneMonth = "1month"
    case threeMonths = "3months"
    case sixMonths = "6months"
    case oneYear = "1year"
    case forever = "forever"
    
    var displayName: String {
        switch self {
        case .oneWeek: return "1 Week"
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .oneYear: return "1 Year"
        case .forever: return "Forever"
        }
    }
}

extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
