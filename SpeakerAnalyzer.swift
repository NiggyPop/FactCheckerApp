//
//  SpeakerAnalyzer.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import AVFoundation
import CoreML
import Accelerate

class SpeakerAnalyzer {
    private let modelURL: URL?
    private var speakerModel: MLModel?
    private let featureExtractor: VoiceFeatureExtractor
    private var knownSpeakers: [String: VoiceProfile] = [:]
    
    private let sampleRate: Double = 16000
    private let frameSize: Int = 512
    private let hopLength: Int = 256
    
    init() {
        self.featureExtractor = VoiceFeatureExtractor()
        self.modelURL = Bundle.main.url(forResource: "SpeakerIdentificationModel", withExtension: "mlmodelc")
        
        loadSpeakerModel()
        loadKnownSpeakers()
    }
    
    // MARK: - Public Methods
    
    func identifySpeaker(from buffer: AVAudioPCMBuffer) async -> SpeakerIdentification? {
        guard let features = extractFeatures(from: buffer) else { return nil }
        
        // Try to identify against known speakers first
        if let knownSpeaker = identifyKnownSpeaker(features: features) {
            return knownSpeaker
        }
        
        // Use ML model for general speaker identification
        return await identifyWithMLModel(features: features)
    }
    
    func registerSpeaker(name: String, audioSamples: [AVAudioPCMBuffer]) async throws {
        var allFeatures: [[Float]] = []
        
        for buffer in audioSamples {
            if let features = extractFeatures(from: buffer) {
                allFeatures.append(features)
            }
        }
        
        guard !allFeatures.isEmpty else {
            throw SpeakerAnalysisError.insufficientData
        }
        
        // Create voice profile
        let profile = createVoiceProfile(from: allFeatures, name: name)
        knownSpeakers[name] = profile
        
        // Save to persistent storage
        try saveKnownSpeakers()
    }
    
    func removeSpeaker(name: String) throws {
        knownSpeakers.removeValue(forKey: name)
        try saveKnownSpeakers()
    }
    
    func getAllKnownSpeakers() -> [String] {
        return Array(knownSpeakers.keys).sorted()
    }
    
    func updateSpeakerProfile(name: String, with newSample: AVAudioPCMBuffer) throws {
        guard var profile = knownSpeakers[name],
              let newFeatures = extractFeatures(from: newSample) else {
            throw SpeakerAnalysisError.speakerNotFound
        }
        
        // Update the profile with new features
        profile.addSample(features: newFeatures)
        knownSpeakers[name] = profile
        
        try saveKnownSpeakers()
    }
    
    // MARK: - Private Methods
    
    private func loadSpeakerModel() {
        guard let modelURL = modelURL else { return }
        
        do {
            speakerModel = try MLModel(contentsOf: modelURL)
        } catch {
            print("Failed to load speaker identification model: \(error)")
        }
    }
    
    private func extractFeatures(from buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        
        let frameCount = Int(buffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        
        // Resample to target sample rate if needed
        let resampledData = resampleIfNeeded(audioData, from: buffer.format.sampleRate, to: sampleRate)
        
        // Extract various voice features
        let mfccFeatures = featureExtractor.extractMFCC(from: resampledData)
        let pitchFeatures = featureExtractor.extractPitchFeatures(from: resampledData)
        let spectralFeatures = featureExtractor.extractSpectralFeatures(from: resampledData)
        let prosodyFeatures = featureExtractor.extractProsodyFeatures(from: resampledData)
        
        // Combine all features
        var combinedFeatures: [Float] = []
        combinedFeatures.append(contentsOf: mfccFeatures)
        combinedFeatures.append(contentsOf: pitchFeatures)
        combinedFeatures.append(contentsOf: spectralFeatures)
        combinedFeatures.append(contentsOf: prosodyFeatures)
        
        return combinedFeatures
    }
    
    private func identifyKnownSpeaker(features: [Float]) -> SpeakerIdentification? {
        var bestMatch: (name: String, similarity: Float) = ("", 0.0)
        
        for (name, profile) in knownSpeakers {
            let similarity = calculateSimilarity(features, profile.averageFeatures)
            if similarity > bestMatch.similarity && similarity > 0.7 { // Threshold for known speaker
                bestMatch = (name, similarity)
            }
        }
        
        guard bestMatch.similarity > 0.0 else { return nil }
        
        let characteristics = estimateVoiceCharacteristics(from: features)
        
        return SpeakerIdentification(
            speakerID: bestMatch.name,
            confidence: bestMatch.similarity,
            voiceCharacteristics: characteristics
        )
    }
    
    private func identifyWithMLModel(features: [Float]) async -> SpeakerIdentification? {
        guard let model = speakerModel else { return nil }
        
        do {
            // Prepare input for ML model
            let inputArray = try MLMultiArray(shape: [1, NSNumber(value: features.count)], dataType: .float32)
            for (index, feature) in features.enumerated() {
                inputArray[index] = NSNumber(value: feature)
            }
            
            // Create input dictionary based on your model's input requirements
            let input = try MLDictionaryFeatureProvider(dictionary: ["audio_features": inputArray])
            
            // Make prediction
            let prediction = try model.prediction(from: input)
            
            // Extract results (adjust based on your model's output)
            if let speakerID = prediction.featureValue(for: "speaker_id")?.stringValue,
               let confidence = prediction.featureValue(for: "confidence")?.doubleValue {
                
                let characteristics = estimateVoiceCharacteristics(from: features)
                
                return SpeakerIdentification(
                    speakerID: speakerID,
                    confidence: Float(confidence),
                    voiceCharacteristics: characteristics
                )
            }
        } catch {
            print("ML model prediction failed: \(error)")
        }
        
        return nil
    }
    
    private func createVoiceProfile(from featureSets: [[Float]], name: String) -> VoiceProfile {
        let featureCount = featureSets.first?.count ?? 0
        var averageFeatures = [Float](repeating: 0, count: featureCount)
        
        // Calculate average features
        for features in featureSets {
            for (index, feature) in features.enumerated() {
                averageFeatures[index] += feature
            }
        }
        
        let sampleCount = Float(featureSets.count)
        for index in 0..<featureCount {
            averageFeatures[index] /= sampleCount
        }
        
        // Calculate variance for each feature
        var featureVariances = [Float](repeating: 0, count: featureCount)
        for features in featureSets {
            for (index, feature) in features.enumerated() {
                let diff = feature - averageFeatures[index]
                featureVariances[index] += diff * diff
            }
        }
        
        for index in 0..<featureCount {
            featureVariances[index] /= sampleCount
        }
        
        return VoiceProfile(
            name: name,
            averageFeatures: averageFeatures,
            featureVariances: featureVariances,
            sampleCount: featureSets.count,
            createdAt: Date()
        )
    }
    
    private func calculateSimilarity(_ features1: [Float], _ features2: [Float]) -> Float {
        guard features1.count == features2.count else { return 0.0 }
        
        // Calculate cosine similarity
        var dotProduct: Float = 0.0
        var norm1: Float = 0.0
        var norm2: Float = 0.0
        
        for i in 0..<features1.count {
            dotProduct += features1[i] * features2[i]
            norm1 += features1[i] * features1[i]
            norm2 += features2[i] * features2[i]
        }
        
        let denominator = sqrt(norm1) * sqrt(norm2)
        return denominator > 0 ? dotProduct / denominator : 0.0
    }
    
    private func estimateVoiceCharacteristics(from features: [Float]) -> VoiceCharacteristics {
        // Extract characteristics from features (simplified)
        // In a real implementation, you'd have specific indices for each characteristic
        
        let pitch = features.count > 13 ? features[13] : 0.0 // Assuming pitch is at index 13
        let tempo = features.count > 14 ? features[14] : 0.0 // Assuming tempo is at index 14
        let volume = features.count > 15 ? features[15] : 0.0 // Assuming volume is at index 15
        
        return VoiceCharacteristics(
            pitch: pitch,
            tempo: tempo,
            volume: volume,
            accent: nil // Would require more sophisticated analysis
        )
    }
    
    private func resampleIfNeeded(_ data: [Float], from sourceRate: Double, to targetRate: Double) -> [Float] {
        guard sourceRate != targetRate else { return data }
        
        let ratio = targetRate / sourceRate
        let newLength = Int(Double(data.count) * ratio)
        var resampledData = [Float](repeating: 0, count: newLength)
        
        // Simple linear interpolation resampling
        for i in 0..<newLength {
            let sourceIndex = Double(i) / ratio
            let lowerIndex = Int(floor(sourceIndex))
            let upperIndex = min(lowerIndex + 1, data.count - 1)
            let fraction = Float(sourceIndex - Double(lowerIndex))
            
            if lowerIndex < data.count {
                resampledData[i] = data[lowerIndex] * (1.0 - fraction) + data[upperIndex] * fraction
            }
        }
        
        return resampledData
    }
    
    // MARK: - Persistence
    
    private func loadKnownSpeakers() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let speakersURL = documentsPath.appendingPathComponent("known_speakers.json")
        
        do {
            let data = try Data(contentsOf: speakersURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            knownSpeakers = try decoder.decode([String: VoiceProfile].self, from: data)
        } catch {
            print("Failed to load known speakers: \(error)")
            knownSpeakers = [:]
        }
    }
    
    private func saveKnownSpeakers() throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let speakersURL = documentsPath.appendingPathComponent("known_speakers.json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(knownSpeakers)
        try data.write(to: speakersURL)
    }
}

// MARK: - Supporting Types

struct VoiceProfile: Codable {
    let name: String
    var averageFeatures: [Float]
    var featureVariances: [Float]
    var sampleCount: Int
    let createdAt: Date
    var lastUpdated: Date
    
    init(name: String, averageFeatures: [Float], featureVariances: [Float], sampleCount: Int, createdAt: Date) {
        self.name = name
        self.averageFeatures = averageFeatures
        self.featureVariances = featureVariances
        self.sampleCount = sampleCount
        self.createdAt = createdAt
        self.lastUpdated = createdAt
    }
    
    mutating func addSample(features: [Float]) {
        guard features.count == averageFeatures.count else { return }
        
        let oldCount = Float(sampleCount)
        let newCount = oldCount + 1.0
        
        // Update running average
        for i in 0..<averageFeatures.count {
            averageFeatures[i] = (averageFeatures[i] * oldCount + features[i]) / newCount
        }
        
        sampleCount += 1
        lastUpdated = Date()
    }
}

class VoiceFeatureExtractor {
    private let fftSetup: FFTSetup
    private let windowSize: Int = 512
    
    init() {
        let log2n = vDSP_Length(log2(Float(windowSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    func extractMFCC(from audioData: [Float]) -> [Float] {
        // Simplified MFCC extraction
        // In a real implementation, you'd use a proper MFCC library
        
        let numCoefficients = 13
        var mfccFeatures = [Float](repeating: 0, count: numCoefficients)
        
        // This is a placeholder - implement proper MFCC extraction
        let windowCount = audioData.count / windowSize
        
        for windowIndex in 0..<windowCount {
            let startIndex = windowIndex * windowSize
            let endIndex = min(startIndex + windowSize, audioData.count)
            let windowData = Array(audioData[startIndex..<endIndex])
            
            // Apply window function and compute spectrum
            let spectrum = computePowerSpectrum(windowData)
            
            // Apply mel filter bank and DCT (simplified)
            for i in 0..<numCoefficients {
                let coefficient = spectrum.prefix(min(spectrum.count, 20)).enumerated().reduce(Float(0)) { sum, element in
                    let (index, value) = element
                    return sum + value * cos(Float(i) * Float(index) * .pi / Float(numCoefficients))
                }
                mfccFeatures[i] += coefficient
            }
        }
        
        // Average across windows
        if windowCount > 0 {
            let count = Float(windowCount)
            for i in 0..<numCoefficients {
                mfccFeatures[i] /= count
            }
        }
        
        return mfccFeatures
    }
    
    func extractPitchFeatures(from audioData: [Float]) -> [Float] {
        // Simplified pitch extraction using autocorrelation
        let minPeriod = 50  // ~800 Hz at 16kHz
        let maxPeriod = 400 // ~40 Hz at 16kHz
        
        var pitchValues: [Float] = []
        let hopSize = 256
        
        for startIndex in stride(from: 0, to: audioData.count - windowSize, by: hopSize) {
            let endIndex = min(startIndex + windowSize, audioData.count)
            let windowData = Array(audioData[startIndex..<endIndex])
            
            let pitch = estimatePitch(windowData, minPeriod: minPeriod, maxPeriod: maxPeriod)
            pitchValues.append(pitch)
        }
        
        // Return pitch statistics
        let avgPitch = pitchValues.reduce(0, +) / Float(pitchValues.count)
        let pitchVariance = pitchValues.reduce(0) { sum, pitch in
            let diff = pitch - avgPitch
            return sum + diff * diff
        } / Float(pitchValues.count)
        
        return [avgPitch, sqrt(pitchVariance)]
    }
    
    func extractSpectralFeatures(from audioData: [Float]) -> [Float] {
        let spectrum = computePowerSpectrum(audioData)
        
        // Spectral centroid
        let spectralCentroid = calculateSpectralCentroid(spectrum)
        
        // Spectral rolloff
        let spectralRolloff = calculateSpectralRolloff(spectrum)
        
        // Spectral flux
        let spectralFlux = calculateSpectralFlux(spectrum)
        
        return [spectralCentroid, spectralRolloff, spectralFlux]
    }
    
    func extractProsodyFeatures(from audioData: [Float]) -> [Float] {
        // Energy-based features
        let energy = audioData.reduce(0) { sum, sample in sum + sample * sample }
        let avgEnergy = energy / Float(audioData.count)
        
        // Zero crossing rate
        var zeroCrossings = 0
        for i in 1..<audioData.count {
            if (audioData[i] >= 0) != (audioData[i-1] >= 0) {
                zeroCrossings += 1
            }
        }
        let zcr = Float(zeroCrossings) / Float(audioData.count)
        
        return [avgEnergy, zcr]
    }
    
    // MARK: - Helper Methods
    
    private func computePowerSpectrum(_ data: [Float]) -> [Float] {
        let paddedSize = max(windowSize, data.count)
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
    
    private func estimatePitch(_ data: [Float], minPeriod: Int, maxPeriod: Int) -> Float {
        var maxCorrelation: Float = 0
        var bestPeriod = minPeriod
        
        for period in minPeriod...maxPeriod {
            var correlation: Float = 0
            let compareLength = min(data.count - period, data.count)
            
            for i in 0..<compareLength {
                correlation += data[i] * data[i + period]
            }
            
            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestPeriod = period
            }
        }
        
        return 16000.0 / Float(bestPeriod) // Convert to Hz assuming 16kHz sample rate
    }
    
    private func calculateSpectralCentroid(_ spectrum: [Float]) -> Float {
        var weightedSum: Float = 0
        var totalMagnitude: Float = 0
        
        for (index, magnitude) in spectrum.enumerated() {
            weightedSum += Float(index) * magnitude
            totalMagnitude += magnitude
        }
        
        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0
    }
    
    private func calculateSpectralRolloff(_ spectrum: [Float]) -> Float {
        let totalEnergy = spectrum.reduce(0, +)
        let threshold = totalEnergy * 0.85
        
        var cumulativeEnergy: Float = 0
        
        for (index, magnitude) in spectrum.enumerated() {
            cumulativeEnergy += magnitude
            if cumulativeEnergy >= threshold {
                return Float(index)
            }
        }
        
        return Float(spectrum.count - 1)
    }
    
    private func calculateSpectralFlux(_ spectrum: [Float]) -> Float {
        // Simplified spectral flux calculation
        // In practice, you'd compare with previous frame
        var flux: Float = 0
        
        for i in 1..<spectrum.count {
            let diff = spectrum[i] - spectrum[i-1]
            flux += max(diff, 0) // Only positive changes
        }
        
        return flux
    }
}

enum SpeakerAnalysisError: Error, LocalizedError {
    case insufficientData
    case speakerNotFound
    case modelLoadFailed
    case featureExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .insufficientData:
            return L("error_insufficient_speaker_data")
        case .speakerNotFound:
            return L("error_speaker_not_found")
        case .modelLoadFailed:
            return L("error_model_load_failed")
        case .featureExtractionFailed:
            return L("error_feature_extraction_failed")
        }
    }
}
