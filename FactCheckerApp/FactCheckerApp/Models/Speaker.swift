//
//  Speaker.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation

struct Speaker: Identifiable, Codable {
    let id: String
    let name: String
    let voiceProfile: VoiceProfile
    let registrationDate: Date
    var lastSeen: Date
    var totalStatements: Int
    var accuracyStats: AccuracyStats
    var isActive: Bool
    
    struct VoiceProfile: Codable {
        let fundamentalFrequency: Double
        let formants: [Double]
        let spectralCentroid: Double
        let mfccCoefficients: [Double]
        let voicePrint: Data
        
        func similarity(to other: VoiceProfile) -> Double {
            // Simplified similarity calculation
            let freqSimilarity = 1.0 - abs(fundamentalFrequency - other.fundamentalFrequency) / max(fundamentalFrequency, other.fundamentalFrequency)
            let spectralSimilarity = 1.0 - abs(spectralCentroid - other.spectralCentroid) / max(spectralCentroid, other.spectralCentroid)
            
            return (freqSimilarity + spectralSimilarity) / 2.0
        }
    }
    
    struct AccuracyStats: Codable {
        var trueStatements: Int = 0
        var falseStatements: Int = 0
        var mixedStatements: Int = 0
        var unknownStatements: Int = 0
        
        var totalVerifiedStatements: Int {
            trueStatements + falseStatements + mixedStatements
        }
        
        var accuracyRate: Double {
            guard totalVerifiedStatements > 0 else { return 0.0 }
            return Double(trueStatements) / Double(totalVerifiedStatements)
        }
        
        var reliabilityScore: Double {
            let total = totalStatements
            guard total > 0 else { return 0.0 }
            
            let verificationRate = Double(totalVerifiedStatements) / Double(total)
            return accuracyRate * verificationRate
        }
        
        mutating func update(with truthLabel: FactCheckResult.TruthLabel) {
            switch truthLabel {
            case .true, .likelyTrue:
                trueStatements += 1
            case .false, .likelyFalse:
                falseStatements += 1
            case .mixed:
                mixedStatements += 1
            case .unknown, .unverifiable:
                unknownStatements += 1
            }
        }
    }
    
    var displayName: String {
        name.isEmpty ? "Speaker \(id.prefix(8))" : name
    }
    
    var statusColor: String {
        switch accuracyStats.reliabilityScore {
        case 0.8...1.0: return "green"
        case 0.6..<0.8: return "yellow"
        case 0.4..<0.6: return "orange"
        default: return "red"
        }
    }
    
    var reliabilityLevel: String {
        switch accuracyStats.reliabilityScore {
        case 0.9...1.0: return "Excellent"
        case 0.8..<0.9: return "Very Good"
        case 0.7..<0.8: return "Good"
        case 0.6..<0.7: return "Fair"
        case 0.5..<0.6: return "Poor"
        default: return "Very Poor"
        }
    }
    
    mutating func updateStats(truthLabel: FactCheckResult.TruthLabel) {
        totalStatements += 1
        accuracyStats.update(with: truthLabel)
        lastSeen = Date()
    }
}
