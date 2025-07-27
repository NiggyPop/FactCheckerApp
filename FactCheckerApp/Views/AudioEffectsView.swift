//
//  AudioEffectsView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI

struct AudioEffectsView: View {
    @StateObject private var effectsProcessor = AudioEffectsProcessor.shared
    @State private var selectedEffects: [AudioEffect] = []
    @State private var showingPreview = false
    @State private var isProcessing = false
    
    let audioFile: AudioFileInfo
    let onEffectsApplied: (URL) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // File Info
                    fileInfoSection
                    
                    // Effects List
                    effectsListSection
                    
                    // Preview and Apply
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Audio Effects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        selectedEffects.removeAll()
                    }
                    .disabled(selectedEffects.isEmpty)
                }
            }
        }
        .overlay(
            Group {
                if isProcessing {
                    ProcessingOverlay(progress: effectsProcessor.processingProgress)
                }
            }
        )
    }
    
    private var fileInfoSection: some View {
        VStack(spacing: 8) {
            Text(audioFile.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            HStack {
                Text(audioFile.format.rawValue.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                
                Text(audioFile.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var effectsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Effects")
                .font(.title3)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 12) {
                NormalizationEffectView(
                    isSelected: selectedEffects.contains { if case .normalization = $0 { return true }; return false },
                    onToggle: { isOn, targetLevel in
                        toggleEffect(.normalization(targetLevel: targetLevel), isOn: isOn)
                    }
                )
                
                NoiseReductionEffectView(
                    isSelected: selectedEffects.contains { if case .noiseReduction = $0 { return true }; return false },
                    onToggle: { isOn, strength in
                        toggleEffect(.noiseReduction(strength: strength), isOn: isOn)
                    }
                )
                
                EqualizerEffectView(
                    isSelected: selectedEffects.contains { if case .equalizer = $0 { return true }; return false },
                    onToggle: { isOn, settings in
                        toggleEffect(.equalizer(settings: settings), isOn: isOn)
                    }
                )
                
                ReverbEffectView(
                    isSelected: selectedEffects.contains { if case .reverb = $0 { return true }; return false },
                    onToggle: { isOn, settings in
                        toggleEffect(.reverb(settings: settings), isOn: isOn)
                    }
                )
                
                CompressionEffectView(
                    isSelected: selectedEffects.contains { if case .compression = $0 { return true }; return false },
                    onToggle: { isOn, settings in
                        toggleEffect(.compression(settings: settings), isOn: isOn)
                    }
                )
                
                TrimSilenceEffectView(
                    isSelected: selectedEffects.contains { if case .trimSilence = $0 { return true }; return false },
                    onToggle: { isOn, threshold in
                        toggleEffect(.trimSilence(threshold: threshold), isOn: isOn)
                    }
                )
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if !selectedEffects.isEmpty {
                Text("\(selectedEffects.count) effect(s) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                Button("Preview") {
                    showingPreview = true
                }
                .buttonStyle(.bordered)
                .disabled(selectedEffects.isEmpty)
                
                Button("Apply Effects") {
                    applyEffects()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedEffects.isEmpty || isProcessing)
            }
        }
        .padding(.top)
    }
    
    private func toggleEffect(_ effect: AudioEffect, isOn: Bool) {
        if isOn {
            // Remove existing effect of same type
            selectedEffects.removeAll { existingEffect in
                switch (effect, existingEffect) {
                case (.normalization, .normalization),
                     (.noiseReduction, .noiseReduction),
                     (.equalizer, .equalizer),
                     (.reverb, .reverb),
                     (.compression, .compression),
                     (.trimSilence, .trimSilence):
                    return true
                default:
                    return false
                }
            }
            selectedEffects.append(effect)
        } else {
            selectedEffects.removeAll { existingEffect in
                switch (effect, existingEffect) {
                case (.normalization, .normalization),
                     (.noiseReduction, .noiseReduction),
                     (.equalizer, .equalizer),
                     (.reverb, .reverb),
                     (.compression, .compression),
                     (.trimSilence, .trimSilence):
                    return true
                default:
                    return false
                }
            }
        }
    }
    
    private func applyEffects() {
        isProcessing = true
        
        Task {
            do {
                let outputURL = AudioFileManager.shared.createTemporaryAudioFile()
                
                try await effectsProcessor.processAudioFile(
                    at: audioFile.url,
                    effects: selectedEffects,
                    outputURL: outputURL
                ) { progress in
                    // Progress is already published by effectsProcessor
                }
                
                await MainActor.run {
                    self.isProcessing = false
                    self.onEffectsApplied(outputURL)
                }
                
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    // Handle error
                    print("Failed to apply effects: \(error)")
                }
            }
        }
    }
}

// MARK: - Effect Views

struct NormalizationEffectView: View {
    let isSelected: Bool
    let onToggle: (Bool, Float) -> Void
    
    @State private var targetLevel: Float = -3.0
    
    var body: some View {
        EffectCardView(
            title: "Normalization",
            description: "Adjust audio levels to optimal volume",
            icon: "waveform.path",
            isSelected: isSelected,
            onToggle: { isOn in onToggle(isOn, targetLevel) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Target Level: \(targetLevel, specifier: "%.1f") dB")
                    .font(.caption)
                
                Slider(value: $targetLevel, in: -12...0, step: 0.5)
                    .onChange(of: targetLevel) { newValue in
                        if isSelected {
                            onToggle(true, newValue)
                        }
                    }
            }
        }
    }
}

struct NoiseReductionEffectView: View {
    let isSelected: Bool
    let onToggle: (Bool, Float) -> Void
    
    @State private var strength: Float = 0.5
    
    var body: some View {
        EffectCardView(
            title: "Noise Reduction",
            description: "Remove background noise and hiss",
            icon: "waveform.path.ecg",
            isSelected: isSelected,
            onToggle: { isOn in onToggle(isOn, strength) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Strength: \(Int(strength * 100))%")
                    .font(.caption)
                
                Slider(value: $strength, in: 0...1, step: 0.1)
                    .onChange(of: strength) { newValue in
                        if isSelected {
                            onToggle(true, newValue)
                        }
                    }
            }
        }
    }
}

struct EqualizerEffectView: View {
    let isSelected: Bool
    let onToggle: (Bool, EqualizerSettings) -> Void
    
    @State private var settings = EqualizerSettings.defaultSettings
    
    var body: some View {
        EffectCardView(
            title: "Equalizer",
            description: "Adjust frequency response",
            icon: "slider.horizontal.3",
            isSelected: isSelected,
            onToggle: { isOn in onToggle(isOn, settings) }
        ) {
            Text("6-band parametric equalizer")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ReverbEffectView: View {
    let isSelected: Bool
    let onToggle: (Bool, ReverbSettings) -> Void
    
    @State private var preset: AVAudioUnitReverbPreset = .mediumRoom
    @State private var wetDryMix: Float = 20
    
    var body: some View {
        EffectCardView(
            title: "Reverb",
            description: "Add spatial ambience",
            icon: "dot.radiowaves.left.and.right",
            isSelected: isSelected,
            onToggle: { isOn in 
                onToggle(isOn, ReverbSettings(preset: preset, wetDryMix: wetDryMix))
            }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Preset", selection: $preset) {
                    Text("Small Room").tag(AVAudioUnitReverbPreset.smallRoom)
                    Text("Medium Room").tag(AVAudioUnitReverbPreset.mediumRoom)
                    Text("Large Room").tag(AVAudioUnitReverbPreset.largeRoom)
                    Text("Cathedral").tag(AVAudioUnitReverbPreset.cathedral)
                }
                .pickerStyle(MenuPickerStyle())
                .font(.caption)
                
                Text("Mix: \(Int(wetDryMix))%")
                    .font(.caption)
                
                Slider(value: $wetDryMix, in: 0...100, step: 5)
            }
            .onChange(of: preset) { _ in updateSettings() }
            .onChange(of: wetDryMix) { _ in updateSettings() }
        }
    }
    
    private func updateSettings() {
        if isSelected {
            onToggle(true, ReverbSettings(preset: preset, wetDryMix: wetDryMix))
        }
    }
}

struct CompressionEffectView: View {
    let isSelected: Bool
    let onToggle: (Bool, CompressionSettings) -> Void
    
    @State private var settings = CompressionSettings.defaultSettings
    
    var body: some View {
        EffectCardView(
            title: "Compression",
            description: "Control dynamic range",
            icon: "waveform.path.badge.minus",
            isSelected: isSelected,
            onToggle: { isOn in onToggle(isOn, settings) }
        ) {
            Text("Dynamic range compression")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TrimSilenceEffectView: View {
    let isSelected: Bool
    let onToggle: (Bool, Float) -> Void
    
    @State private var threshold: Float = 0.01
    
    var body: some View {
        EffectCardView(
            title: "Trim Silence",
            description: "Remove silence from beginning and end",
            icon: "scissors",
            isSelected: isSelected,
            onToggle: { isOn in onToggle(isOn, threshold) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Threshold: \(Int(threshold * 100))%")
                    .font(.caption)
                
                Slider(value: $threshold, in: 0.001...0.1, step: 0.001)
                    .onChange(of: threshold) { newValue in
                        if isSelected {
                            onToggle(true, newValue)
                        }
                    }
            }
        }
    }
}

struct EffectCardView<Content: View>: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    let content: Content
    
    init(
        title: String,
        description: String,
        icon: String,
        isSelected: Bool,
        onToggle: @escaping (Bool) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .font(.title3)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
            }
            
            if isSelected {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ProcessingOverlay: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Processing Audio...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}
