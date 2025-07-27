//
//  SettingsView 2.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI

struct SettingsView: View {
    @AppStorage("recordingQuality") private var recordingQuality = RecordingQuality.high
    @AppStorage("autoSaveRecordings") private var autoSaveRecordings = true
    @AppStorage("showWaveformDuringRecording") private var showWaveformDuringRecording = true
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("maxRecordingDuration") private var maxRecordingDuration = 3600.0 // 1 hour
    @AppStorage("audioFormat") private var audioFormat = AudioFileFormat.m4a
    @AppStorage("enableBackgroundRecording") private var enableBackgroundRecording = false
    @AppStorage("autoTrimSilence") private var autoTrimSilence = false
    @AppStorage("enableCloudSync") private var enableCloudSync = false
    
    @State private var showingStorageInfo = false
    @State private var showingAbout = false
    @State private var showingExportOptions = false
    
    var body: some View {
        NavigationView {
            Form {
                recordingSection
                playbackSection
                storageSection
                privacySection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingStorageInfo) {
                StorageInfoView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView()
            }
        }
    }
    
    private var recordingSection: some View {
        Section("Recording") {
            Picker("Audio Quality", selection: $recordingQuality) {
                ForEach(RecordingQuality.allCases, id: \.self) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }
            
            Picker("Audio Format", selection: $audioFormat) {
                ForEach(AudioFileFormat.allCases, id: \.self) { format in
                    Text(format.rawValue.uppercased()).tag(format)
                }
            }
            
            Toggle("Auto-save Recordings", isOn: $autoSaveRecordings)
            
            Toggle("Show Waveform", isOn: $showWaveformDuringRecording)
            
            Toggle("Background Recording", isOn: $enableBackgroundRecording)
            
            Toggle("Auto-trim Silence", isOn: $autoTrimSilence)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Max Recording Duration")
                
                HStack {
                    Text(formatDuration(maxRecordingDuration))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Slider(
                        value: $maxRecordingDuration,
                        in: 300...7200, // 5 minutes to 2 hours
                        step: 300
                    )
                    .frame(width: 150)
                }
            }
        }
    }
    
    private var playbackSection: some View {
        Section("Playback") {
            Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
            
            NavigationLink("Audio Effects") {
                AudioEffectsSettingsView()
            }
            
            NavigationLink("Equalizer Presets") {
                EqualizerPresetsView()
            }
        }
    }
    
    private var storageSection: some View {
        Section("Storage") {
            Button("Storage Usage") {
                showingStorageInfo = true
            }
            
            Toggle("iCloud Sync", isOn: $enableCloudSync)
            
            Button("Export Settings") {
                showingExportOptions = true
            }
            
            Button("Clean Temporary Files") {
                AudioFileManager.shared.cleanupTemporaryFiles()
            }
            
            Button("Reset All Settings") {
                resetAllSettings()
            }
            .foregroundColor(.red)
        }
    }
    
    private var privacySection: some View {
        Section("Privacy") {
            NavigationLink("Microphone Access") {
                MicrophonePermissionView()
            }
            
            NavigationLink("Data Usage") {
                DataUsageView()
            }
            
            Button("Privacy Policy") {
                // Open privacy policy
            }
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }
            
            Button("About Voice Recorder") {
                showingAbout = true
            }
            
            Button("Rate App") {
                // Open App Store rating
            }
            
            Button("Contact Support") {
                // Open support email
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func resetAllSettings() {
        recordingQuality = .high
        autoSaveRecordings = true
        showWaveformDuringRecording = true
        enableHapticFeedback = true
        maxRecordingDuration = 3600.0
        audioFormat = .m4a
        enableBackgroundRecording = false
        autoTrimSilence = false
        enableCloudSync = false
    }
}

struct AudioEffectsSettingsView: View {
    @AppStorage("defaultNormalizationLevel") private var defaultNormalizationLevel = -3.0
    @AppStorage("defaultNoiseReductionStrength") private var defaultNoiseReductionStrength = 0.5
    @AppStorage("enableAutoEffects") private var enableAutoEffects = false
    
    var body: some View {
        Form {
            Section("Default Effect Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Normalization Level: \(defaultNormalizationLevel, specifier: "%.1f") dB")
                    Slider(value: $defaultNormalizationLevel, in: -12...0, step: 0.5)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Noise Reduction: \(Int(defaultNoiseReductionStrength * 100))%")
                    Slider(value: $defaultNoiseReductionStrength, in: 0...1, step: 0.1)
                }
            }
            
            Section("Auto Effects") {
                Toggle("Apply Effects Automatically", isOn: $enableAutoEffects)
                
                if enableAutoEffects {
                    Text("Automatically apply normalization and noise reduction to new recordings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Audio Effects")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EqualizerPresetsView: View {
    @State private var presets: [EqualizerPreset] = EqualizerPreset.defaultPresets
    @State private var showingCreatePreset = false
    
    var body: some View {
        List {
            ForEach(presets) { preset in
                EqualizerPresetRow(preset: preset)
            }
            .onDelete(perform: deletePresets)
        }
        .navigationTitle("EQ Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    showingCreatePreset = true
                }
            }
        }
        .sheet(isPresented: $showingCreatePreset) {
            CreateEqualizerPresetView { preset in
                presets.append(preset)
            }
        }
    }
    
    private func deletePresets(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
    }
}

struct EqualizerPresetRow: View {
    let preset: EqualizerPreset
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preset.name)
                .font(.headline)
            
            Text(preset.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Simple frequency response visualization
            HStack(spacing: 2) {
                ForEach(preset.settings.bands, id: \.frequency) { band in
                    Rectangle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: 8, height: max(4, 20 + band.gain * 2))
                }
            }
            .frame(height: 40)
        }
        .padding(.vertical, 4)
    }
}

struct CreateEqualizerPresetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var settings = EqualizerSettings.defaultSettings
    
    let onSave: (EqualizerPreset) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Preset Info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section("Equalizer Settings") {
                    Text("Configure your equalizer bands here")
                        .foregroundColor(.secondary)
                    // Add EQ band controls here
                }
            }
            .navigationTitle("New EQ Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let preset = EqualizerPreset(
                            name: name,
                            description: description,
                            settings: settings
                        )
                        onSave(preset)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct MicrophonePermissionView: View {
    @State private var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Microphone Access")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Voice Recorder needs access to your microphone to record audio.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Status:")
                    Spacer()
                    Text(permissionStatusText)
                        .foregroundColor(permissionStatusColor)
                }
                
                if permissionStatus == .denied {
                    Button("Open Settings") {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else if permissionStatus == .undetermined {
                    Button("Request Permission") {
                        requestMicrophonePermission()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Microphone Access")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkPermissionStatus()
        }
    }
    
    private var permissionStatusText: String {
        switch permissionStatus {
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .undetermined:
            return "Not Requested"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var permissionStatusColor: Color {
        switch permissionStatus {
        case .granted:
            return .green
        case .denied:
            return .red
        case .undetermined:
            return .orange
        @unknown default:
            return .secondary
        }
    }
    
    private func checkPermissionStatus() {
        permissionStatus = AVAudioSession.sharedInstance().recordPermission
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.permissionStatus = granted ? .granted : .denied
            }
        }
    }
}

struct DataUsageView: View {
    @State private var storageInfo: StorageInfo?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 24) {
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let info = storageInfo {
                dataUsageContent(info)
            } else {
                Text("Unable to load data usage information")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .navigationTitle("Data Usage")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDataUsage()
        }
    }
    
    private func dataUsageContent(_ info: StorageInfo) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Text("Local Storage")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    DataUsageRow(
                        title: "Audio Files",
                        value: info.formattedTotalSize,
                        icon: "waveform"
                    )
                    
                    DataUsageRow(
                        title: "Temporary Files",
                        value: "0 KB", // Would calculate actual temp file size
                        icon: "doc.badge.clock"
                    )
                    
                    DataUsageRow(
                        title: "App Data",
                        value: "< 1 MB", // Settings, preferences, etc.
                        icon: "gear"
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            VStack(spacing: 16) {
                Text("Privacy Information")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("• Audio recordings are stored locally on your device")
                    Text("• No data is transmitted to external servers")
                    Text("• iCloud sync (if enabled) uses Apple's secure infrastructure")
                    Text("• You have full control over your recordings")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Spacer()
        }
    }
    
    private func loadDataUsage() {
        isLoading = true
        
        Task {
            let info = AudioFileManager.shared.getStorageUsage()
            
            await MainActor.run {
                self.storageInfo = info
                self.isLoading = false
            }
        }
    }
}

struct DataUsageRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // App Icon and Info
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Voice Recorder")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Voice Recorder is a powerful and intuitive audio recording app designed for iOS. Record high-quality audio, apply professional effects, and manage your recordings with ease.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "mic.fill", text: "High-quality audio recording")
                            FeatureRow(icon: "waveform.path", text: "Real-time waveform visualization")
                            FeatureRow(icon: "slider.horizontal.3", text: "Professional audio effects")
                            FeatureRow(icon: "icloud", text: "iCloud synchronization")
                            FeatureRow(icon: "square.and.arrow.up", text: "Easy sharing and export")
                            FeatureRow(icon: "lock.shield", text: "Privacy-focused design")
                        }
                    }
                    
                    // Credits
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Credits")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Developed with ❤️ using SwiftUI and AVFoundation")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct ExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Settings") {
                    Button("Export as JSON") {
                        exportSettings()
                    }
                    
                    Button("Import Settings") {
                        importSettings()
                    }
                }
                
                Section("Backup") {
                    Button("Create Backup") {
                        createBackup()
                    }
                    
                    Button("Restore from Backup") {
                        restoreBackup()
                    }
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportSettings() {
        // Implement settings export
    }
    
    private func importSettings() {
        // Implement settings import
    }
    
    private func createBackup() {
        // Implement backup creation
    }
    
    private func restoreBackup() {
        // Implement backup restoration
    }
}

// MARK: - Supporting Types

struct EqualizerPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let settings: EqualizerSettings
    
    static let defaultPresets = [
        EqualizerPreset(
            name: "Flat",
            description: "No equalization applied",
            settings: EqualizerSettings.defaultSettings
        ),
        EqualizerPreset(
            name: "Voice",
            description: "Optimized for speech recording",
            settings: EqualizerSettings.defaultSettings // Would have voice-specific settings
        ),
        EqualizerPreset(
            name: "Music",
            description: "Enhanced for music recording",
            settings: EqualizerSettings.defaultSettings // Would have music-specific settings
        )
    ]
}

enum RecordingQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case lossless = "lossless"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low (22 kHz)"
        case .medium:
            return "Medium (44.1 kHz)"
        case .high:
            return "High (48 kHz)"
        case .lossless:
            return "Lossless (96 kHz)"
        }
    }
    
    var sampleRate: Double {
        switch self {
        case .low:
            return 22050
        case .medium:
            return 44100
        case .high:
            return 48000
        case .lossless:
            return 96000
        }
    }
}
