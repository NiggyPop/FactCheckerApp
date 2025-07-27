//
//  AudioQualityAnalyzer.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import AVFoundation
import Accelerate

class AudioQualityAnalyzer {
    private let fftSetup: FFTSetup
    private let bufferSize: Int = 4096
    
    init() {
        let log2n = vDSP_Length(log2(Float(bufferSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    func analyzeQuality(_ buffer: AVAudioPCMBuffer) -> AudioQuality {
        guard let channelData = buffer.floatChannelData?[0] else {
            return AudioQuality(score: 0, issues: [.noSignal], recommendations: ["Check microphone connection"])
        }
        
        let frameCount = Int(buffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        
        var qualityScore: Float = 1.0
        var issues: [AudioQualityIssue] = []
        var recommendations: [String] = []
        
        // Analyze signal level
        let (signalScore, signalIssues, signalRecs) = analyzeSignalLevel(audioData)
        qualityScore *= signalScore
        issues.append(contentsOf: signalIssues)
        recommendations.append(contentsOf: signalRecs)
        
        // Analyze noise level
        let (noiseScore, noiseIssues, noiseRecs) = analyzeNoiseLevel(audioData)
        qualityScore *= noiseScore
        issues.append(contentsOf: noiseIssues)
        recommendations.append(contentsOf: noiseRecs)
        
        // Analyze clipping
        let (clippingScore, clippingIssues, clippingRecs) = analyzeClipping(audioData)
        qualityScore *= clippingScore
        issues.append(contentsOf: clippingIssues)
        recommendations.append(contentsOf: clippingRecs)
        
        // Analyze frequency response
        let (freqScore, freqIssues, freqRecs) = analyzeFrequencyResponse(audioData)
        qualityScore *= freqScore
        issues.append(contentsOf: freqIssues)
        recommendations.append(contentsOf: freqRecs)
        
        // Analyze dynamic range
        let (dynamicScore, dynamicIssues, dynamicRecs) = analyzeDynamicRange(audioData)
        qualityScore *= dynamicScore
        issues.append(contentsOf: dynamicIssues)
        recommendations.append(contentsOf: dynamicRecs)
        
        return AudioQuality(
            score: qualityScore,
            issues: issues,
            recommendations: recommendations
        )
    }
    
    // MARK: - Analysis Methods
    
    private func analyzeSignalLevel(_ data: [Float]) -> (Float, [AudioQualityIssue], [String]) {
        let rms = calculateRMS(data)
        let dbLevel = 20 * log10(rms)
        
        var score: Float = 1.0
        var issues: [AudioQualityIssue] = []
        var recommendations: [String] = []
        
        if dbLevel < -40 {
            score = 0.3
            issues.append(.lowSignalLevel)
            recommendations.append("Move closer to the microphone or increase input gain")
        } else if dbLevel < -30 {
            score = 0.6
            issues.append(.lowSignalLevel)
            recommendations.append("Consider increasing input volume slightly")
        } else if dbLevel > -6 {
            score = 0.4
            issues.append(.highSignalLevel)
            recommendations.append("Reduce input gain to prevent distortion")
        }
        
        return (score, issues, recommendations)
    }
    
    private func analyzeNoiseLevel(_ data: [Float]) -> (Float, [AudioQualityIssue], [String]) {
        // Estimate noise floor using quieter segments
        let sortedData = data.map { abs($0) }.sorted()
        let noiseFloor = sortedData[sortedData.count / 10] // Bottom 10%
        let signal = calculateRMS(data)
        
        let snr = 20 * log10(signal / max(noiseFloor, 1e-10))
        
        var score: Float = 1.0
        var issues: [AudioQualityIssue] = []
        var recommendations: [String] = []
        
        if snr < 20 {
            score = 0.4
            issues.append(.highNoiseLevel)
            recommendations.append("Use noise reduction or move to a quieter environment")
        } else if snr < 30 {
            score = 0.7
            issues.append(.moderateNoise)
            recommendations.append("Consider using noise reduction")
        }
        
        return (score, issues, recommendations)
    }
    
    private func analyzeClipping(_ data: [Float]) -> (Float, [AudioQualityIssue], [String]) {
        let threshold: Float = 0.95
        let clippedSamples = data.filter { abs($0) >= threshold }.count
        let clippingPercentage = Float(clippedSamples) / Float(data.count)
        
        var score: Float = 1.0
        var issues: [AudioQualityIssue] = []
        var recommendations: [String] = []
        
        if clippingPercentage > 0.01 { // More than 1% clipped
            score = 0.2
            issues.append(.clipping)
            recommendations.append("Reduce input gain to prevent clipping distortion")
        } else if clippingPercentage > 0.001 { // More than 0.1% clipped
            score = 0.6
            issues.append(.occasionalClipping)
            recommendations.append("Slightly reduce input gain")
        }
        
        return (score, issues, recommendations)
    }
    
    private func analyzeFrequencyResponse(_ data: [Float]) -> (Float, [AudioQualityIssue], [String]) {
        let spectrum = computePowerSpectrum(data)
        
        // Analyze speech frequency bands
        let lowBand = spectrum[0..<spectrum.count/8].reduce(0, +) // 0-2.75kHz
        let midBand = spectrum[spectrum.count/8..<spectrum.count/4].reduce(0, +) // 2.75-5.5kHz
        let highBand = spectrum[spectrum.count/4..<spectrum.count/2].reduce(0, +) // 5.5-11kHz
        
        let totalEnergy = lowBand + midBand + highBand
        
        var score: Float = 1.0
        var issues: [AudioQualityIssue] = []
        var recommendations: [String] = []
        
        if totalEnergy > 0 {
            let lowRatio = lowBand / totalEnergy
            let midRatio = midBand / totalEnergy
            let highRatio = highBand / totalEnergy
            
            // Check for frequency imbalances
            if lowRatio > 0.7 {
                score *= 0.7
                issues.append(.poorFrequencyResponse)
                recommendations.append("Audio sounds muffled - check microphone placement")
            }
            
            if midRatio < 0.2 {
                score *= 0.8
                issues.append(.poorFrequencyResponse)
                recommendations.append("Lack of mid-frequency content affects speech clarity")
            }
            
            if highRatio > 0.5 {
                score *= 0.8
                issues.append(.poorFrequencyResponse)
                recommendations.append("Excessive high frequencies - may sound harsh")
            }
        }
        
        return (score, issues, recommendations)
    }
    
    private func analyzeDynamicRange(_ data: [Float]) -> (Float, [AudioQualityIssue], [String]) {
        let sortedData = data.map { abs($0) }.sorted()
        let peak = sortedData.last ?? 0
        let rms = calculateRMS(data)
        
        let crestFactor = peak / max(rms, 1e-10)
        let dynamicRange = 20 * log10(crestFactor)
        
        var score: Float = 1.0
        var issues: [AudioQualityIssue] = []
        var recommendations: [String] = []
        
        if dynamicRange < 6 {
            score = 0.5
            issues.append(.limitedDynamicRange)
            recommendations.append("Audio appears over-compressed - check processing settings")
        } else if dynamicRange > 20 {
            score = 0.7
            issues.append(.excessiveDynamicRange)
            recommendations.append("Large volume variations - consider using compression")
        }
        
        return (score, issues, recommendations)
    }
    
    // MARK: - Helper Methods
    
    private func calculateRMS(_ data: [Float]) -> Float {
        let sumOfSquares = data.reduce(0) { sum, sample in sum + sample * sample }
        return sqrt(sumOfSquares / Float(data.count))
    }
    
    private func computePowerSpectrum(_ data: [Float]) -> [Float] {
        let paddedSize = max(bufferSize, data.count)
        var paddedData = data + [Float](repeating: 0, count: paddedSize - data.count)
        
        var realParts = [Float](repeating: 0, count: paddedSize / 2)
        var imagParts = [Float](repeating: 0, count: paddedSize / 2)
        var powerSpectrum = [Float](repeating: 0, count: paddedSize / 2)
        
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        
        paddedData.withUnsafeBufferPointer { dataPtr in
            dataPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: paddedSize / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(paddedSize / 2))
            }
        }
        
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(paddedSize))), FFTDirection(FFT_FORWARD))
        vDSP_zvmags(&splitComplex, 1, &powerSpectrum, 1, vDSP_Length(paddedSize / 2))
        
        return powerSpectrum
    }
}

// MARK: - Supporting Types

struct AudioQuality {
    let score: Float
    let issues: [AudioQualityIssue]
    let recommendations: [String]
    
    var description: String {
        switch score {
        case 0.8...1.0:
            return "Excellent"
        case 0.6..<0.8:
            return "Good"
        case 0.4..<0.6:
            return "Fair"
        case 0.2..<0.4:
            return "Poor"
        default:
            return "Very Poor"
        }
    }
    
    var color: UIColor {
        switch score {
        case 0.8...1.0:
            return .systemGreen
        case 0.6..<0.8:
            return .systemBlue
        case 0.4..<0.6:
            return .systemYellow
        case 0.2..<0.4:
            return .systemOrange
        default:
            return .systemRed
        }
    }
}

enum AudioQualityIssue {
    case noSignal
    case lowSignalLevel
    case highSignalLevel
    case highNoiseLevel
    case moderateNoise
    case clipping
    case occasionalClipping
    case poorFrequencyResponse
    case limitedDynamicRange
    case excessiveDynamicRange
    
    var description: String {
        switch self {
        case .noSignal:
            return "No audio signal detected"
        case .lowSignalLevel:
            return "Signal level too low"
        case .highSignalLevel:
            return "Signal level too high"
        case .highNoiseLevel:
            return "High background noise"
        case .moderateNoise:
            return "Moderate background noise"
        case .clipping:
            return "Audio clipping detected"
        case .occasionalClipping:
            return "Occasional clipping"
        case .poorFrequencyResponse:
            return "Poor frequency response"
        case .limitedDynamicRange:
            return "Limited dynamic range"
        case .excessiveDynamicRange:
            return "Excessive dynamic range"
        }
    }
}
