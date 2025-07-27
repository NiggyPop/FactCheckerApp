//
//  AudioVisualizerView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI
import AVFoundation

struct AudioVisualizerView: View {
    @StateObject private var audioLevelMonitor = AudioLevelMonitor()
    let isRecording: Bool
    let audioPlayer: AVAudioPlayer?
    
    private let numberOfBars = 20
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 2
    
    var body: some View {
        HStack(alignment: .center, spacing: barSpacing) {
            ForEach(0..<numberOfBars, id: \.self) { index in
                VisualizerBar(
                    height: barHeight(for: index),
                    color: barColor(for: index)
                )
                .frame(width: barWidth)
            }
        }
        .onAppear {
            if isRecording {
                audioLevelMonitor.startMonitoring()
            }
        }
        .onDisappear {
            audioLevelMonitor.stopMonitoring()
        }
        .onChange(of: isRecording) { recording in
            if recording {
                audioLevelMonitor.startMonitoring()
            } else {
                audioLevelMonitor.stopMonitoring()
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 40
        
        if isRecording {
            // Use actual audio levels for recording
            let level = audioLevelMonitor.audioLevels[safe: index] ?? 0
            return baseHeight + (maxHeight - baseHeight) * CGFloat(level)
        } else if let player = audioPlayer, player.isPlaying {
            // Simulate visualization for playback
            let normalizedIndex = Double(index) / Double(numberOfBars)
            let animationOffset = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 2.0)
            let wave = sin(normalizedIndex * .pi * 2 + animationOffset * .pi)
            return baseHeight + (maxHeight - baseHeight) * CGFloat(abs(wave)) * 0.7
        } else {
            return baseHeight
        }
    }
    
    private func barColor(for index: Int) -> Color {
        if isRecording {
            let level = audioLevelMonitor.audioLevels[safe: index] ?? 0
            if level > 0.8 {
                return .red
            } else if level > 0.5 {
                return .orange
            } else {
                return .green
            }
        } else {
            return .blue
        }
    }
}

struct VisualizerBar: View {
    let height: CGFloat
    let color: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(height: height)
            .animation(.easeInOut(duration: 0.1), value: height)
    }
}

class AudioLevelMonitor: ObservableObject {
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 20)
    
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var timer: Timer?
    
    func startMonitoring() {
        setupAudioEngine()
        startTimer()
    }
    
    func stopMonitoring() {
        audioEngine.stop()
        timer?.invalidate()
        timer = nil
        
        DispatchQueue.main.async {
            self.audioLevels = Array(repeating: 0, count: 20)
        }
    }
    
    private func setupAudioEngine() {
        inputNode = audioEngine.inputNode
        let format = inputNode?.outputFormat(forBus: 0)
        
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameCount = Int(buffer.frameLength)
        let samplesPerBar = max(1, frameCount / audioLevels.count)
        
        var newLevels: [Float] = []
        
        for i in 0..<audioLevels.count {
            let startIndex = i * samplesPerBar
            let endIndex = min(startIndex + samplesPerBar, frameCount)
            
            var sum: Float = 0
            for j in startIndex..<endIndex {
                sum += abs(channelData[j])
            }
            
            let average = sum / Float(endIndex - startIndex)
            newLevels.append(min(average * 10, 1.0)) // Amplify and clamp
        }
        
        DispatchQueue.main.async {
            self.audioLevels = newLevels
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // Timer keeps the visualization smooth
        }
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
