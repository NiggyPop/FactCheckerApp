//
//  WaveformView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI
import AVFoundation
import Accelerate

struct WaveformView: View {
    let audioURL: URL?
    let samples: [Float]
    let isRecording: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    
    @State private var waveformSamples: [Float] = []
    @State private var isProcessing = false
    
    private let maxSamples = 200
    private let minBarHeight: CGFloat = 2
    private let maxBarHeight: CGFloat = 50
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 1) {
                ForEach(0..<displaySamples.count, id: \.self) { index in
                    WaveformBar(
                        height: barHeight(for: displaySamples[index]),
                        isActive: isBarActive(at: index, geometry: geometry),
                        isRecording: isRecording
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        .onAppear {
            if let url = audioURL {
                loadWaveform(from: url)
            }
        }
        .onChange(of: audioURL) { newURL in
            if let url = newURL {
                loadWaveform(from: url)
            }
        }
        .onChange(of: samples) { newSamples in
            if isRecording {
                updateRecordingWaveform(with: newSamples)
            }
        }
    }
    
    private var displaySamples: [Float] {
        if isRecording {
            return Array(samples.suffix(maxSamples))
        } else {
            return waveformSamples
        }
    }
    
    private func barHeight(for sample: Float) -> CGFloat {
        let normalizedSample = min(abs(sample), 1.0)
        return minBarHeight + (maxBarHeight - minBarHeight) * CGFloat(normalizedSample)
    }
    
    private func isBarActive(at index: Int, geometry: GeometryProxy) -> Bool {
        guard !isRecording && duration > 0 else { return false }
        
        let progress = currentTime / duration
        let activeIndex = Int(progress * Double(displaySamples.count))
        return index <= activeIndex
    }
    
    private func loadWaveform(from url: URL) {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        Task {
            do {
                let samples = try await generateWaveformSamples(from: url)
                
                await MainActor.run {
                    self.waveformSamples = samples
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.waveformSamples = []
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func updateRecordingWaveform(with newSamples: [Float]) {
        // Smooth animation for recording waveform
        withAnimation(.easeInOut(duration: 0.1)) {
            // Update is handled by displaySamples computed property
        }
    }
    
    private func generateWaveformSamples(from url: URL) async throws -> [Float] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let audioFile = try AVAudioFile(forReading: url)
                    let format = audioFile.processingFormat
                    let frameCount = AVAudioFrameCount(audioFile.length)
                    
                    guard let buffer = AVAudioPCMBuffer(
                        pcmFormat: format,
                        frameCapacity: frameCount
                    ) else {
                        continuation.resume(throwing: WaveformError.bufferCreationFailed)
                        return
                    }
                    
                    try audioFile.read(into: buffer)
                    
                    guard let channelData = buffer.floatChannelData?[0] else {
                        continuation.resume(throwing: WaveformError.noChannelData)
                        return
                    }
                    
                    let samples = self.downsampleAudio(
                        channelData: channelData,
                        frameCount: Int(buffer.frameLength),
                        targetSampleCount: self.maxSamples
                    )
                    
                    continuation.resume(returning: samples)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func downsampleAudio(
        channelData: UnsafeMutablePointer<Float>,
        frameCount: Int,
        targetSampleCount: Int
    ) -> [Float] {
        guard frameCount > 0 && targetSampleCount > 0 else { return [] }
        
        let samplesPerBin = frameCount / targetSampleCount
        var downsampledData: [Float] = []
        
        for i in 0..<targetSampleCount {
            let startIndex = i * samplesPerBin
            let endIndex = min(startIndex + samplesPerBin, frameCount)
            
            var maxSample: Float = 0
            
            // Find the maximum absolute value in this bin
            for j in startIndex..<endIndex {
                let sample = abs(channelData[j])
                if sample > maxSample {
                    maxSample = sample
                }
            }
            
            downsampledData.append(maxSample)
        }
        
        return downsampledData
    }
}

struct WaveformBar: View {
    let height: CGFloat
    let isActive: Bool
    let isRecording: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(barColor)
            .frame(width: 2, height: height)
            .animation(.easeInOut(duration: 0.1), value: height)
    }
    
    private var barColor: Color {
        if isRecording {
            return .red
        } else if isActive {
            return .blue
        } else {
            return .gray.opacity(0.5)
        }
    }
}

enum WaveformError: Error {
    case bufferCreationFailed
    case noChannelData
    case processingFailed
}
