//
//  TimestampedTranscriptionView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI
import AVFoundation

struct TimestampedTranscriptionView: View {
    let audioURL: URL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var transcriptionManager = TranscriptionManager()
    @StateObject private var audioPlayer = AudioPlayerManager()
    
    @State private var transcriptionSegments: [TranscriptionSegment] = []
    @State private var isTranscribing = false
    @State private var selectedLanguage = "en-US"
    @State private var currentPlaybackTime: TimeInterval = 0
    @State private var highlightedSegmentIndex: Int?
    
    private let availableLanguages = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("es-ES", "Spanish"),
        ("fr-FR", "French"),
        ("de-DE", "German")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Audio player controls
                audioPlayerSection
                
                Divider()
                
                // Transcription content
                transcriptionContentSection
            }
            .navigationTitle("Timestamped Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Export with Timestamps") {
                            exportWithTimestamps()
                        }
                        .disabled(transcriptionSegments.isEmpty)
                        
                        Button("Export Text Only") {
                            exportTextOnly()
                        }
                        .disabled(transcriptionSegments.isEmpty)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                setupAudioPlayer()
            }
            .onDisappear {
                audioPlayer.stop()
            }
        }
    }
    
    private var audioPlayerSection: some View {
        VStack(spacing: 16) {
            // Playback controls
            HStack(spacing: 20) {
                Button(action: { audioPlayer.seekBackward(10) }) {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                }
                
                Button(action: togglePlayback) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                }
                
                Button(action: { audioPlayer.seekForward(10) }) {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                }
            }
            
            // Progress bar
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { currentPlaybackTime },
                        set: { audioPlayer.seek(to: $0) }
                    ),
                    in: 0...audioPlayer.duration
                )
                
                HStack {
                    Text(AudioFileInfo.formatDuration(currentPlaybackTime))
                        .font(.caption)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(AudioFileInfo.formatDuration(audioPlayer.duration))
                        .font(.caption)
                        .monospacedDigit()
                }
                .foregroundColor(.secondary)
            }
            
            // Transcription controls
            if transcriptionSegments.isEmpty {
                Button(action: startTranscription) {
                    HStack {
                        if isTranscribing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Transcribing...")
                        } else {
                            Image(systemName: "text.bubble")
                            Text("Start Transcription")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isTranscribing ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isTranscribing)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
    }
    
    private var transcriptionContentSection: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(transcriptionSegments.enumerated()), id: \.offset) { index, segment in
                    TranscriptionSegmentRow(
                        segment: segment,
                        isHighlighted: highlightedSegmentIndex == index,
                        onTap: {
                            audioPlayer.seek(to: segment.startTime)
                            HapticFeedbackManager.shared.buttonTapped()
                        }
                    )
                    .id(index)
                }
            }
            .listStyle(PlainListStyle())
            .onChange(of: highlightedSegmentIndex) { index in
                if let index = index {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func setupAudioPlayer() {
        audioPlayer.setupPlayer(with: audioURL)
        
        // Monitor playback time
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentPlaybackTime = audioPlayer.currentTime
            updateHighlightedSegment()
        }
    }
    
    private func togglePlayback() {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.play()
        }
        HapticFeedbackManager.shared.buttonTapped()
    }
    
    private func startTranscription() {
        isTranscribing = true
        
        transcriptionManager.transcribeAudioWithTimestamps(
            url: audioURL,
            language: selectedLanguage
        ) { result in
            DispatchQueue.main.async {
                self.isTranscribing = false
                
                switch result {
                case .success(let segments):
                    self.transcriptionSegments = segments
                    HapticFeedbackManager.shared.effectApplied()
                    
                case .failure(let error):
                    print("Transcription failed: \(error)")
                    HapticFeedbackManager.shared.errorOccurred()
                }
            }
        }
    }
    
    private func updateHighlightedSegment() {
        let currentIndex = transcriptionSegments.firstIndex { segment in
            currentPlaybackTime >= segment.startTime && currentPlaybackTime <= segment.endTime
        }
        
        if highlightedSegmentIndex != currentIndex {
            highlightedSegmentIndex = currentIndex
        }
    }
    
    private func exportWithTimestamps() {
        let content = transcriptionSegments.map { segment in
            let startTime = AudioFileInfo.formatDuration(segment.startTime)
            let endTime = AudioFileInfo.formatDuration(segment.endTime)
            return "[\(startTime) - \(endTime)] \(segment.text)"
        }.joined(separator: "\n\n")
        
        exportContent(content, fileName: "Timestamped_Transcription")
    }
    
    private func exportTextOnly() {
        let content = transcriptionSegments.map { $0.text }.joined(separator: " ")
        exportContent(content, fileName: "Transcription")
    }
    
    private func exportContent(_ content: String, fileName: String) {
        let fullFileName = "\(fileName)_\(DateFormatter.exportFormatter.string(from: Date())).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fullFileName)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            // Present share sheet
            let shareSheet = ShareSheet(items: [tempURL])
            // Implementation would need to present this sheet
        } catch {
            print("Failed to export transcription: \(error)")
            HapticFeedbackManager.shared.errorOccurred()
        }
    }
}

struct TranscriptionSegmentRow: View {
    let segment: TranscriptionSegment
    let isHighlighted: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Timestamp
                VStack(alignment: .leading, spacing: 2) {
                    Text(AudioFileInfo.formatDuration(segment.startTime))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isHighlighted ? .white : .blue)
                    
                    Text(AudioFileInfo.formatDuration(segment.endTime))
                        .font(.caption2)
                        .foregroundColor(isHighlighted ? .white.opacity(0.8) : .secondary)
                }
                .frame(width: 60, alignment: .leading)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(segment.text)
                        .font(.body)
                        .foregroundColor(isHighlighted ? .white : .primary)
                        .multilineTextAlignment(.leading)
                    
                    // Confidence indicator
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Circle()
                                .fill(confidenceColor(for: segment.confidence, index: index))
                                .frame(width: 4, height: 4)
                        }
                        
                        Text("\(Int(segment.confidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(isHighlighted ? .white.opacity(0.7) : .secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHighlighted ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func confidenceColor(for confidence: Float, index: Int) -> Color {
        let threshold = Float(index + 1) / 5.0
        if confidence >= threshold {
            return isHighlighted ? .white : .green
        } else {
            return isHighlighted ? .white.opacity(0.3) : .gray.opacity(0.3)
        }
    }
}
