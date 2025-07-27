//
//  AdvancedVisualizerView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI
import Accelerate

struct AdvancedVisualizerView: View {
    @ObservedObject var audioService: AudioService
    @State private var frequencyData: [Float] = Array(repeating: 0, count: 64)
    @State private var animationTimer: Timer?
    
    let barCount = 64
    let barSpacing: CGFloat = 2
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .blue.opacity(0.3),
                                    .blue,
                                    .purple
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(
                            width: (geometry.size.width - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount),
                            height: max(2, CGFloat(frequencyData[index]) * geometry.size.height)
                        )
                        .animation(.easeInOut(duration: 0.1), value: frequencyData[index])
                }
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateFrequencyData()
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateFrequencyData() {
        // Get FFT data from audio service
        let fftData = audioService.getFFTData()
        
        // Process and normalize the data
        let processedData = processFFTData(fftData)
        
        withAnimation(.easeInOut(duration: 0.1)) {
            frequencyData = processedData
        }
    }
    
    private func processFFTData(_ data: [Float]) -> [Float] {
        guard data.count >= barCount else {
            return Array(repeating: 0, count: barCount)
        }
        
        var processedData: [Float] = []
        let chunkSize = data.count / barCount
        
        for i in 0..<barCount {
            let startIndex = i * chunkSize
            let endIndex = min(startIndex + chunkSize, data.count)
            let chunk = Array(data[startIndex..<endIndex])
            
            // Calculate RMS for this frequency band
            let rms = sqrt(chunk.map { $0 * $0 }.reduce(0, +) / Float(chunk.count))
            
            // Apply logarithmic scaling and normalization
            let normalized = min(1.0, log10(1 + rms * 9) / log10(10))
            processedData.append(normalized)
        }
        
        return processedData
    }
}
