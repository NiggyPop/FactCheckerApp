//
//  FactCheckResult.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation

struct FactCheckResult: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let speakerId: String
    let statement: String
    let confidence: Double
    let truthLabel: TruthLabel
    let truthScore: Double
    let sources: [RealTimeSource]
    let explanation: String
    let claimType: ClaimType
    let keyEntities: [String]
    let sentiment: Double
    
    enum TruthLabel: String, CaseIterable, Codable {
        case `true` = "True"
        case likelyTrue = "Likely True"
        case mixed = "Mixed"
        case likelyFalse = "Likely False"
        case `false` = "False"
        case unknown = "Unknown"
        case unverifiable = "Unverifiable"
        
        var color: String {
            switch self {
            case .true: return "green"
            case .likelyTrue: return "mint"
            case .mixed: return "yellow"
            case .likelyFalse: return "orange"
            case .false: return "red"
            case .unknown: return "gray"
            case .unverifiable: return "purple"
            }
        }
        
        var icon: String {
            switch self {
            case .true: return "checkmark.circle.fill"
            case .likelyTrue: return "checkmark.circle"
            case .mixed: return "questionmark.circle.fill"
            case .likelyFalse: return "xmark.circle"
            case .false: return "xmark.circle.fill"
            case .unknown: return "questionmark.circle"
            case .unverifiable: return "exclamationmark.circle"
            }
        }
        
        var description: String {
            switch self {
            case .true: return "This claim is supported by reliable evidence"
            case .likelyTrue: return "This claim appears to be accurate"
            case .mixed: return "This claim contains both accurate and inaccurate elements"
            case .likelyFalse: return "This claim appears to be inaccurate"
            case .false: return "This claim is contradicted by reliable evidence"
            case .unknown: return "Insufficient information to verify this claim"
            case .unverifiable: return "This claim cannot be verified with available sources"
            }
        }
    }
    
    var accuracyPercentage: Int {
        Int(truthScore * 100)
    }
    
    var highQualitySources: [RealTimeSource] {
        sources.filter { $0.credibilityScore > 0.8 }
    }
    
    var averageSourceCredibility: Double {
        guard !sources.isEmpty else { return 0.0 }
        return sources.reduce(0.0) { $0 + $1.credibilityScore } / Double(sources.count)
    }
}

enum ClaimType: String, CaseIterable, Codable {
    case statistical = "Statistical"
    case medical = "Medical"
    case scientific = "Scientific"
    case historical = "Historical"
    case political = "Political"
    case economic = "Economic"
    case legal = "Legal"
    case environmental = "Environmental"
    case general = "General"
    
    var icon: String {
        switch self {
        case .statistical: return "chart.bar.fill"
        case .medical: return "cross.fill"
        case .scientific: return "flask.fill"
        case .historical: return "clock.fill"
        case .political: return "building.columns.fill"
        case .economic: return "dollarsign.circle.fill"
        case .legal: return "scale.3d"
        case .environmental: return "leaf.fill"
        case .general: return "info.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .statistical: return "blue"
        case .medical: return "red"
        case .scientific: return "cyan"
        case .historical: return "brown"
        case .political: return "purple"
        case .economic: return "green"
        case .legal: return "indigo"
        case .environmental: return "mint"
        case .general: return "gray"
        }
    }
}
