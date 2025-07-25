//
//  TranscriptSegment.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation

struct TranscriptSegment: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    var processed: Bool
    var speakerId: String?
    var confidence: Double
    var audioFeatures: AudioFeatures?
    
    init(id: UUID = UUID(), content: String, timestamp: Date, processed: Bool = false, speakerId: String? = nil, confidence: Double = 1.0) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.processed = processed
        self.speakerId = speakerId
        self.confidence = confidence
    }
    
    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    var duration: TimeInterval {
        // Estimate based on average speaking rate (150 words per minute)
        Double(wordCount) / 150.0 * 60.0
    }
    
    var isSignificant: Bool {
        wordCount >= 5 && confidence > 0.7
    }
    
    func containsFactualClaim() -> Bool {
        let lowercased = content.lowercased()
        
        // Skip questions
        if content.hasSuffix("?") || lowercased.hasPrefix("what") || lowercased.hasPrefix("how") {
            return false
        }
        
        // Look for factual indicators
        let factualIndicators = [
            "percent", "%", "million", "billion", "according to", "studies show",
            "research indicates", "data shows", "statistics", "evidence"
        ]
        
        return factualIndicators.contains { lowercased.contains($0) }
    }
}

struct AudioFeatures: Codable {
    let fundamentalFrequency: Double
    let energy: Double
    let spectralCentroid: Double
    let zeroCrossingRate: Double
    let mfccCoefficients: [Double]
    
    static func extract(from audioData: [Float]) -> AudioFeatures {
        // Simplified feature extraction
        let energy = audioData.reduce(0) { $0 + $1 * $1 } / Float(audioData.count)
        let zeroCrossings = zip(audioData, audioData.dropFirst()).reduce(0) { count, pair in
            count + ((pair.0 * pair.1 < 0) ? 1 : 0)
        }
        let zcr = Double(zeroCrossings) / Double(audioData.count - 1)
        
        return AudioFeatures(
            fundamentalFrequency: 150.0, // Placeholder
            energy: Double(energy),
            spectralCentroid: 1000.0, // Placeholder
            zeroCrossingRate: zcr,
            mfccCoefficients: Array(repeating: 0.0, count: 13) // Placeholder
        )
    }
}
