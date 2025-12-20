//
//  InvestigationModels.swift
//  FactCheckerApp
//
//  Created by OpenAI Assistant on 7/13/24.
//

import Foundation

struct InvestigatedDocument: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    let fileSize: Int64
    let importedAt: Date
    let textPreview: String
    let detectedFigures: [PublicFigure]
    let connections: [ConnectionInsight]
    let events: [TimelineEvent]
}

struct PublicFigure: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let role: String
    let confidence: Double
    let mentions: Int
    let relatedEntities: [String]
    
    static func == (lhs: PublicFigure, rhs: PublicFigure) -> Bool {
        lhs.name == rhs.name && lhs.role == rhs.role
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(role)
    }
}

struct ConnectionInsight: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let confidence: Double
    let relatedFigures: [String]
    let type: ConnectionType
}

enum ConnectionType: String, Codable, CaseIterable, Hashable {
    case realEstate = "Real Estate"
    case financial = "Financial"
    case political = "Political"
    case legal = "Legal"
    case business = "Business"
    case other = "Other"
    
    var iconName: String {
        switch self {
        case .realEstate: return "house.fill"
        case .financial: return "banknote.fill"
        case .political: return "building.columns"
        case .legal: return "scales"
        case .business: return "briefcase.fill"
        case .other: return "sparkles"
        }
    }
    
    var colorName: String {
        switch self {
        case .realEstate: return "blue"
        case .financial: return "green"
        case .political: return "purple"
        case .legal: return "indigo"
        case .business: return "orange"
        case .other: return "gray"
        }
    }
}

struct TimelineEvent: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let title: String
    let context: String
    let linkedFigures: [String]
    let sourceFile: String
    let relevanceScore: Double
}

struct InvestigationSummary {
    let documentsCount: Int
    let figureCount: Int
    let connectionCount: Int
    let eventCount: Int
}
