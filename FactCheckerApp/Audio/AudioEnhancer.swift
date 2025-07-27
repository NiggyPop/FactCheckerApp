//
//  AudioEnhancer.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import AVFoundation
import Accelerate

class AudioEnhancer {
    private let fftSetup: FFTSetup
    private let bufferSize: Int = 4096
    private let sampleRate: Double = 44100
    
    // Enhancement parameters
    private var dynamicRangeCompressor: DynamicRangeCompressor
    private var equalizerBands: [EqualizerBand]
    private var adaptiveGainControl: AdaptiveGainControl
    
    init() {
        let log2n = vDSP_Length(log2(Float(bufferSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        dynamicRangeCompressor = DynamicRangeCompressor()
        adaptiveGainControl = AdaptiveGainControl()
        
        // Initialize equalizer bands for speech enhancement
        equalizerBands = [
            EqualizerBand(frequency: 300, gain: 1.2, q: 0.7),   // Low-mid boost for warmth
            EqualizerBand(frequency: 1000, gain: 1.5, q: 1.0),  // Mid boost for clarity
            EqualizerBand(frequency: 3000, gain: 1.8, q: 1.2),  // High-mid boost for intelligibility
            EqualizerBand(frequency: 6000, gain: 1.3, q: 0.8),  // Presence boost
            EqualizerBand(frequency: 60, gain: 0.7, q: 0.5),    // Low cut for rumble
            EqualizerBand(frequency: 12000, gain: 0.9, q: 0.6)  // High cut for harshness
        ]
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    func enhance(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let inputData = buffer.floatChannelData?[0],
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        
        let frameCount = Int(buffer.frameLength)
        let outputData = outputBuffer.floatChannelData![0]
        
        // Copy input to output for processing
        memcpy(outputData, inputData, frameCount * MemoryLayout<Float>.size)
        
        // Apply enhancement chain
        applyPreEmphasis(outputData, frameCount: frameCount)
        applyEqualizer(outputData, frameCount: frameCount)
        applyDynamicRangeCompression(outputData, frameCount: frameCount)
        applyAdaptiveGainControl(outputData, frameCount: frameCount)
        applyDeEsser(outputData, frameCount: frameCount)
        
        outputBuffer.frameLength = buffer.frameLength
        return outputBuffer
    }
    
    // MARK: - Enhancement Algorithms
    
    private func applyPreEmphasis(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Pre-emphasis filter to boost high frequencies
        let alpha: Float = 0.97
        
        for i in stride(from: frameCount - 1, through: 1, by: -1) {
            data[i] = data[i] - alpha * data[i - 1]
        }
    }
    
    private func applyEqualizer(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        let audioData = Array(UnsafeBufferPointer(start: data, count: frameCount))
        var processedData = audioData
        
        // Apply each equalizer band
        for band in equalizerBands {
            processedData = applyBiquadFilter(processedData, band: band)
        }
        
        // Copy back to buffer
        for i in 0..<frameCount {
            data[i] = processedData[i]
        }
    }
    
    private func applyBiquadFilter(_ input: [Float], band: EqualizerBand) -> [Float] {
        let omega = 2.0 * Float.pi * band.frequency / Float(sampleRate)
        let sin_omega = sin(omega)
        let cos_omega = cos(omega)
        let alpha = sin_omega / (2.0 * band.q)
        let A = sqrt(band.gain)
        
        // Peaking EQ coefficients
        let b0 = 1.0 + alpha * A
        let b1 = -2.0 * cos_omega
        let b2 = 1.0 - alpha * A
        let a0 = 1.0 + alpha / A
        let a1 = -2.0 * cos_omega
        let a2 = 1.0 - alpha / A
        
        // Normalize coefficients
        let norm = 1.0 / a0
        let nb0 = b0 * norm
        let nb1 = b1 * norm
        let nb2 = b2 * norm
        let na1 = a1 * norm
        let na2 = a2 * norm
        
        var output = [Float](repeating: 0, count: input.count)
        var x1: Float = 0, x2: Float = 0
        var y1: Float = 0, y2: Float = 0
        
        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = nb0 * x0 + nb1 * x1 + nb2 * x2 - na1 * y1 - na2 * y2
            
            output[i] = y0
            
            x2 = x1; x1 = x0
            y2 = y1; y1 = y0
        }
        
        return output
    }
    
    private func applyDynamicRangeCompression(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        dynamicRangeCompressor.process(data, frameCount: frameCount)
    }
    
    private func applyAdaptiveGainControl(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        adaptiveGainControl.process(data, frameCount: frameCount)
    }
    
    private func applyDeEsser(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Simple de-esser to reduce harsh sibilants
        let threshold: Float = 0.3
        let ratio: Float = 3.0
        let frequency: Float = 6000 // Target sibilant frequency
        
        // High-pass filter to isolate sibilants
        let audioData = Array(UnsafeBufferPointer(start: data, count: frameCount))
        let sibilantBand = applyBiquadFilter(audioData, band: EqualizerBand(frequency: frequency, gain: 1.0, q: 2.0))
        
        for i in 0..<frameCount {
            let sibilantLevel = abs(sibilantBand[i])
            
            if sibilantLevel > threshold {
                let excess = sibilantLevel - threshold
                let reduction = excess / ratio
                let gainReduction = 1.0 - (reduction / sibilantLevel)
                
                data[i] *= gainReduction
            }
        }
    }
}

// MARK: - Supporting Classes

class DynamicRangeCompressor {
    private var envelope: Float = 0.0
    private let threshold: Float = -20.0 // dB
    private let ratio: Float = 4.0
    private let attackTime: Float = 0.003 // 3ms
    private let releaseTime: Float = 0.1 // 100ms
    private let sampleRate: Float = 44100
    
    private lazy var attackCoeff: Float = exp(-1.0 / (attackTime * sampleRate))
    private lazy var releaseCoeff: Float = exp(-1.0 / (releaseTime * sampleRate))
    
    func process(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        let thresholdLinear = pow(10.0, threshold / 20.0)
        
        for i in 0..<frameCount {
            let inputLevel = abs(data[i])
            
            // Envelope follower
            let targetEnvelope = inputLevel
            if targetEnvelope > envelope {
                envelope = targetEnvelope + (envelope - targetEnvelope) * attackCoeff
            } else {
                envelope = targetEnvelope + (envelope - targetEnvelope) * releaseCoeff
            }
            
            // Apply compression
            if envelope > thresholdLinear {
                let overThreshold = envelope / thresholdLinear
                let compressedGain = pow(overThreshold, (1.0 / ratio) - 1.0)
                data[i] *= compressedGain
            }
        }
    }
}

class AdaptiveGainControl {
    private var targetLevel: Float = 0.5
    private var currentGain: Float = 1.0
    private var levelHistory: [Float] = []
    private let historySize = 1000
    private let adaptationRate: Float = 0.001
    
    func process(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Calculate RMS level
        var rms: Float = 0.0
        for i in 0..<frameCount {
            rms += data[i] * data[i]
        }
        rms = sqrt(rms / Float(frameCount))
        
        // Update level history
        levelHistory.append(rms)
        if levelHistory.count > historySize {
            levelHistory.removeFirst()
        }
        
        // Calculate average level
        let averageLevel = levelHistory.reduce(0, +) / Float(levelHistory.count)
        
        // Adapt gain
        if averageLevel > 0 {
            let desiredGain = targetLevel / averageLevel
            currentGain += (desiredGain - currentGain) * adaptationRate
            
            // Limit gain range
            currentGain = max(0.1, min(currentGain, 10.0))
        }
        
        // Apply gain
        for i in 0..<frameCount {
            data[i] *= currentGain
        }
    }
}

struct EqualizerBand {
    let frequency: Float
    let gain: Float
    let q: Float
}
