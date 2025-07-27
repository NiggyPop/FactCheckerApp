//
//  AudioPlayerView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI

struct AudioPlayerView: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    @State private var showingSpeedMenu = false
    @State private var showingVolumeSlider = false
    
    let file: AudioFileInfo
    
    var body: some View {
        VStack(spacing: 24) {
            // File Info
            fileInfoSection
            
            // Waveform Visualization (placeholder)
            waveformVisualization
            
            // Progress Slider
            progressSlider
            
            // Playback Controls
            playbackControls
            
            // Additional Controls
            additionalControls
        }
        .padding()
        .background(Color(.systemBackground))
        .onAppear {
            playerManager.loadFile(file)
        }
        .onChange(of: playerManager.currentTime) { newTime in
            if !isDraggingSlider {
                sliderValue = newTime
            }
        }
    }
    
    private var fileInfoSection: some View {
        VStack(spacing: 8) {
            Text(file.name)
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Text(file.format.rawValue.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                
                Text(file.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatDuration(playerManager.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var waveformVisualization: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 80)
            
            // Placeholder waveform
            HStack(spacing: 2) {
                ForEach(0..<50, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: 3, height: CGFloat.random(in: 10...60))
                }
            }
            .animation(.easeInOut(duration: 0.5), value: playerManager.isPlaying)
        }
    }
    
    private var progressSlider: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { isDraggingSlider ? sliderValue : playerManager.currentTime },
                    set: { newValue in
                        sliderValue = newValue
                        if !isDraggingSlider {
                            playerManager.seek(to: newValue)
                        }
                    }
                ),
                in: 0...max(playerManager.duration, 1),
                onEditingChanged: { editing in
                    isDraggingSlider = editing
                    if !editing {
                        playerManager.seek(to: sliderValue)
                    }
                }
            )
            .accentColor(.blue)
            
            HStack {
                Text(formatDuration(playerManager.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                Text("-\(formatDuration(playerManager.duration - playerManager.currentTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    private var playbackControls: some View {
        HStack(spacing: 40) {
            // Skip Backward
            Button(action: { playerManager.skipBackward(15) }) {
                Image(systemName: "gobackward.15")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            // Play/Pause
            Button(action: togglePlayback) {
                Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }
            
            // Skip Forward
            Button(action: { playerManager.skipForward(15) }) {
                Image(systemName: "goforward.15")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var additionalControls: some View {
        HStack(spacing: 24) {
            // Loop Toggle
            Button(action: { playerManager.toggleLoop() }) {
                Image(systemName: playerManager.isLooping ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundColor(playerManager.isLooping ? .blue : .secondary)
            }
            
            Spacer()
            
            // Playback Speed
            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                    Button("\(speed, specifier: "%.2g")x") {
                        playerManager.setPlaybackRate(Float(speed))
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                    Text("\(playerManager.playbackRate, specifier: "%.2g")x")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            // Volume Control
            Button(action: { showingVolumeSlider.toggle() }) {
                Image(systemName: volumeIcon)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .popover(isPresented: $showingVolumeSlider) {
                VolumeSliderView(volume: $playerManager.volume)
                    .frame(width: 200, height: 100)
                    .padding()
            }
        }
    }
    
    private var volumeIcon: String {
        switch playerManager.volume {
        case 0:
            return "speaker.slash"
        case 0..<0.33:
            return "speaker.1"
        case 0.33..<0.66:
            return "speaker.2"
        default:
            return "speaker.3"
        }
    }
    
    private func togglePlayback() {
        if playerManager.isPlaying {
            playerManager.pause()
        } else {
            playerManager.play()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VolumeSliderView: View {
    @Binding var volume: Float
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Volume")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "speaker.1")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: Binding(
                    get: { Double(volume) },
                    set: { volume = Float($0) }
                ), in: 0...1)
                .accentColor(.blue)
                
                Image(systemName: "speaker.3")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(Int(volume * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}

struct AudioPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let file: AudioFileInfo
    
    var body: some View {
        NavigationView {
            AudioPlayerView(file: file)
                .navigationTitle("Audio Player")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            ShareLink(item: file.url) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Button("Show in Files") {
                                // Open file location
                            }
                            
                            Button("Delete", role: .destructive) {
                                // Delete file with confirmation
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
        }
    }
}
