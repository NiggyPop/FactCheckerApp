//
//  SpeakerIdentificationService.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import AVFoundation
import Combine

class SpeakerIdentificationService: ObservableObject {
    @Published var currentSpeaker: String = "Unknown"
    @Published var registeredSpeakers: [Speaker] = []
    @Published var confidence: Double = 0.0
    @Published var isTraining = false
    
    private var cancellables = Set<AnyCancellable>()
    private let similarityThreshold: Double = 0.8
    private var audioBuffer: [Float] = []
    private let bufferSize = 4096
    
    init() {
        loadRegisteredSpeakers()
    }
    
    func startListening(to audioPublisher: AnyPublisher<[Float], Never>) {
        audioPublisher
            .sink { [weak self] audioData in
                self?.processAudioData(audioData)
            }
            .store(in: &cancellables)
    }
    
    private func processAudioData(_ audioData: [Float]) {
        audioBuffer.append(contentsOf: audioData)
        
        if audioBuffer.count >= bufferSize {
            let features = extractVoiceFeatures(from: Array(audioBuffer.prefix(bufferSize)))
            identifySpeaker(from: features)
            
            // Keep only the last quarter of the buffer for continuity
            audioBuffer = Array(audioBuffer.suffix(bufferSize / 4))
        }
    }
    
    private func extractVoiceFeatures(from audioData: [Float]) -> Speaker.VoiceProfile {
        // Simplified feature extraction
        let fundamentalFreq = estimateFundamentalFrequency(audioData)
        let spectralCentroid = calculateSpectralCentroid(audioData)
        let formants = estimateFormants(audioData)
        let mfcc = calculateMFCC(audioData)
        
        return Speaker.VoiceProfile(
            fundamentalFrequency: fundamentalFreq,
            formants: formants,
            spectralCentroid: spectralCentroid,
            mfccCoefficients: mfcc,
            voicePrint: Data() // Simplified
        )
    }
    
    private func identifySpeaker(from voiceProfile: Speaker.VoiceProfile) {
        var bestMatch: Speaker?
        var bestSimilarity: Double = 0.0
        
        for speaker in registeredSpeakers {
            let similarity = voiceProfile.similarity(to: speaker.voiceProfile)
            if similarity > bestSimilarity && similarity > similarityThreshold {
                bestSimilarity = similarity
                bestMatch = speaker
            }
        }
        
        DispatchQueue.main.async {
            if let match = bestMatch {
                self.currentSpeaker = match.id
                self.confidence = bestSimilarity
            } else {
                self.currentSpeaker = "Unknown"
                self.confidence = 0.0
            }
        }
    }
    
    func registerSpeaker(name: String, audioSamples: [[Float]], completion: @escaping (Result<Speaker, Error>) -> Void) {
        guard !audioSamples.isEmpty else {
            completion(.failure(SpeakerError.insufficientData))
            return
        }
        
        isTraining = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Extract features from all samples and average them
            let profiles = audioSamples.map { self.extractVoiceFeatures(from: $0) }
            let averagedProfile = self.averageVoiceProfiles(profiles)
            
            let speaker = Speaker(
                id: UUID().uuidString,
                name: name,
                voiceProfile: averagedProfile,
                registrationDate: Date(),
                lastSeen: Date(),
                totalStatements: 0,
                accuracyStats: Speaker.AccuracyStats(),
                isActive: true
            )
            
            DispatchQueue.main.async {
                self.registeredSpeakers.append(speaker)
                self.saveRegisteredSpeakers()
                self.isTraining = false
                completion(.success(speaker))
            }
        }
    }
    
    private func averageVoiceProfiles(_ profiles: [Speaker.VoiceProfile]) -> Speaker.VoiceProfile {
        let avgFundamentalFreq = profiles.reduce(0.0) { $0 + $1.fundamentalFrequency } / Double(profiles.count)
        let avgSpectralCentroid = profiles.reduce(0.0) { $0 + $1.spectralCentroid } / Double(profiles.count)
        
        // Average formants
        let maxFormants = profiles.map { $0.formants.count }.max() ?? 0
        var avgFormants: [Double] = []
        for i in 0..<maxFormants {
            let sum = profiles.compactMap { $0.formants.count > i ? $0.formants[i] : nil }.reduce(0.0, +)
            let count = profiles.filter { $0.formants.count > i }.count
            avgFormants.append(count > 0 ? sum / Double(count) : 0.0)
        }
        
        // Average MFCC
        let maxMFCC = profiles.map { $0.mfccCoefficients.count }.max() ?? 0
        var avgMFCC: [Double] = []
        for i in 0..<maxMFCC {
            let sum = profiles.compactMap { $0.mfccCoefficients.count > i ? $0.mfccCoefficients[i] : nil }.reduce(0.0, +)
            let count = profiles.filter { $0.mfccCoefficients.count > i }.count
            avgMFCC.append(count > 0 ? sum / Double(count) : 0.0)
        }
        
        return Speaker.VoiceProfile(
            fundamentalFrequency: avgFundamentalFreq,
            formants: avgFormants,
            spectralCentroid: avgSpectralCentroid,
            mfccCoefficients: avgMFCC,
            voicePrint: Data()
        )
    }
    
    func updateSpeakerStats(speakerId: String, truthLabel: FactCheckResult.TruthLabel) {
        if let index = registeredSpeakers.firstIndex(where: { $0.id == speakerId }) {
            registeredSpeakers[index].updateStats(truthLabel: truthLabel)
            saveRegisteredSpeakers()
        }
    }
    
    func removeSpeaker(_ speaker: Speaker) {
        registeredSpeakers.removeAll { $0.id == speaker.id }
        saveRegisteredSpeakers()
    }
    
    private func saveRegisteredSpeakers() {
        if let data = try? JSONEncoder().encode(registeredSpeakers) {
            UserDefaults.standard.set(data, forKey: "RegisteredSpeakers")
        }
    }
    
    private func loadRegisteredSpeakers() {
        if let data = UserDefaults.standard.data(forKey: "RegisteredSpeakers"),
           let speakers = try? JSONDecoder().decode([Speaker].self, from: data) {
            registeredSpeakers = speakers
        }
    }
    
    // MARK: - Audio Processing Helpers
    
    private func estimateFundamentalFrequency(_ audioData: [Float]) -> Double {
        // Simplified autocorrelation-based pitch detection
        let sampleRate: Double = 44100.0
        let minPeriod = Int(sampleRate / 800.0) // 800 Hz max
        let maxPeriod = Int(sampleRate / 80.0)  // 80 Hz min
        
        var bestPeriod = minPeriod
        var maxCorrelation: Float = 0.0
        
        for period in minPeriod...min(maxPeriod, audioData.count / 2) {
            var correlation: Float = 0.0
            let samples = min(audioData.count - period, 1000)
            
            for i in 0..<samples {
                correlation += audioData[i] * audioData[i + period]
            }
            
            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestPeriod = period
            }
        }
        
        return sampleRate / Double(bestPeriod)
    }
    
    private func calculateSpectralCentroid(_ audioData: [Float]) -> Double {
        // Simplified spectral centroid calculation
        let fft = performFFT(audioData)
        let magnitudes = fft.map { sqrt($0.real * $0.real + $0.imag * $0.imag) }
        
        var weightedSum: Double = 0.0
        var magnitudeSum: Double = 0.0
        
        for (index, magnitude) in magnitudes.enumerated() {
            let frequency = Double(index) * 44100.0 / Double(magnitudes.count)
            weightedSum += frequency * Double(magnitude)
            magnitudeSum += Double(magnitude)
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0
    }
    
    private func estimateFormants(_ audioData: [Float]) -> [Double] {
        // Simplified formant estimation
        let fft = performFFT(audioData)
        let magnitudes = fft.map { sqrt($0.real * $0.real + $0.imag * $0.imag) }
        
        // Find peaks in the spectrum (simplified)
        var formants: [Double] = []
        let windowSize = 10
        
        for i in windowSize..<(magnitudes.count - windowSize) {
            let current = magnitudes[i]
            let isLocalMax = (i-windowSize..<i).allSatisfy { magnitudes[$0] <= current } &&
                           (i+1...i+windowSize).allSatisfy { magnitudes[$0] <= current }
            
            if isLocalMax && current > 0.1 && formants.count < 4 {
                let frequency = Double(i) * 44100.0 / Double(magnitudes.count)
                if frequency > 200 && frequency < 4000 { // Typical formant range
                    formants.append(frequency)
                }
            }
        }
        
        return formants
    }
    
    private func calculateMFCC(_ audioData: [Float]) -> [Double] {
        // Simplified MFCC calculation (normally requires mel filter banks)
        let fft = performFFT(audioData)
        let powerSpectrum = fft.map { $0.real * $0.real + $0.imag * $0.imag }
        
        // Apply log and DCT (simplified)
        let logSpectrum = powerSpectrum.map { log(max($0, 1e-10)) }
        
        // Return first 13 coefficients (simplified DCT)
        return Array(logSpectrum.prefix(13))
    }
    
    private func performFFT(_ audioData: [Float]) -> [(real: Float, imag: Float)] {
        // Simplified FFT implementation (in practice, use Accelerate framework)
        let n = audioData.count
        var result: [(real: Float, imag: Float)] = []
        
        for k in 0..<n {
            var real: Float = 0.0
            var imag: Float = 0.0
            
            for j in 0..<n {
                let angle = -2.0 * Float.pi * Float(k * j) / Float(n)
                real += audioData[j] * cos(angle)
                imag += audioData[j] * sin(angle)
            }
            
            result.append((real: real, imag: imag))
        }
        
        return result
    }
}

enum SpeakerError: Error, LocalizedError {
    case insufficientData
    case registrationFailed
    case speakerNotFound
    
    var errorDescription: String? {
        switch self {
        case .insufficientData:
            return "Insufficient audio data for speaker registration"
        case .registrationFailed:
            return "Failed to register speaker"
        case .speakerNotFound:
            return "Speaker not found"
        }
    }
}
