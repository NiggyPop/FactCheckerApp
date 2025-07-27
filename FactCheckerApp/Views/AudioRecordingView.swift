//
//  AudioRecordingView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI
import AVFoundation

struct AudioRecordingView: View {
    @StateObject private var audioProcessor = AdvancedAudioProcessor()
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingPermissionAlert = false
    @State private var permissionError: String?
    
    var body: some View {
        VStack(spacing: 30) {
            // Audio Level Visualization
            audioLevelVisualization
            
            // Recording Status
            recordingStatusView
            
            // Main Recording Button
            recordingButton
            
            // Audio Quality Indicator
            audioQualityView
            
            // Transcription Display
            transcriptionView
            
            // Speaker Identification
            speakerIdentificationView
            
            Spacer()
        }
        .padding()
        .navigationTitle("Audio Recording")
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionError ?? "Microphone access is required for audio recording.")
        }
    }
    
    private var audioLevelVisualization: some View {
        VStack(spacing: 16) {
            Text("Audio Level")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: CGFloat(audioProcessor.audioLevel))
                    .stroke(
                        LinearGradient(
                            colors: [.green, .yellow, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.1), value: audioProcessor.audioLevel)
                
                VStack {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    Text("\(Int(audioProcessor.audioLevel * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    private var recordingStatusView: some View {
        VStack(spacing: 8) {
            if isRecording {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: isRecording)
                    
                    Text("Recording")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                
                Text(formatDuration(recordingDuration))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            } else {
                Text("Ready to Record")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var recordingButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
                
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var audioQualityView: some View {
        VStack(spacing: 8) {
            Text("Audio Quality")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Circle()
                    .fill(Color(audioProcessor.audioQuality.color))
                    .frame(width: 12, height: 12)
                
                Text(audioProcessor.audioQuality.description)
                    .font(.body)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var transcriptionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Transcription")
                .font(.headline)
            
            ScrollView {
                Text(audioProcessor.transcriptionText.isEmpty ? "Start speaking to see transcription..." : audioProcessor.transcriptionText)
                    .font(.body)
                    .foregroundColor(audioProcessor.transcriptionText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 120)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    private var speakerIdentificationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speaker Identification")
                .font(.headline)
            
            if let speaker = audioProcessor.speakerIdentification {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        
                        Text(speaker.speakerID)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(speaker.confidence * 100))%")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    // Voice characteristics
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voice Characteristics:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            VoiceCharacteristicView(
                                title: "Pitch",
                                value: speaker.voiceCharacteristics.pitch,
                                range: 0...1
                            )
                            
                            VoiceCharacteristicView(
                                title: "Tempo",
                                value: speaker.voiceCharacteristics.tempo,
                                range: 0...1
                            )
                            
                            VoiceCharacteristicView(
                                title: "Volume",
                                value: speaker.voiceCharacteristics.volume,
                                range: 0...1
                            )
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                Text("No speaker identified")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        Task {
            do {
                try await audioProcessor.startRecording()
                
                await MainActor.run {
                    isRecording = true
                    recordingDuration = 0
                    startTimer()
                }
            } catch {
                await MainActor.run {
                    handleRecordingError(error)
                }
            }
        }
    }
    
    private func stopRecording() {
        audioProcessor.stopRecording()
        isRecording = false
        stopTimer()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func handleRecordingError(_ error: Error) {
        if let audioError = error as? AudioProcessingError {
            switch audioError {
            case .microphonePermissionDenied:
                permissionError = "Microphone access is required to record audio. Please enable it in Settings."
            case .speechRecognitionPermissionDenied:
                permissionError = "Speech recognition access is required for transcription. Please enable it in Settings."
            default:
                permissionError = audioError.localizedDescription
            }
        } else {
            permissionError = error.localizedDescription
        }
        
        showingPermissionAlert = true
    }
    
    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
}

struct VoiceCharacteristicView: View {
    let title: String
    let value: Float
    let range: ClosedRange<Float>
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ProgressView(value: Double(value), in: Double(range.lowerBound)...Double(range.upperBound))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(height: 4)
            
            Text(String(format: "%.1f", value))
                .font(.caption2)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
