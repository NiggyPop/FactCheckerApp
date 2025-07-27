//
//  RealTimeSource.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation

struct RealTimeSource: Identifiable, Codable {
    let id = UUID()
    let title: String
    let url: String
    let domain: String
    let credibilityScore: Double
    let lastUpdated: Date
    let relevanceScore: Double
    let sourceType: SourceType
    let excerpt: String?
    let author: String?
    let publishDate: Date?
    let language: String?
    let country: String?
    
    enum SourceType: String, CaseIterable, Codable {
        case academic = "Academic"
        case government = "Government"
        case news = "News"
        case factCheck = "Fact Check"
        case research = "Research"
        case medical = "Medical"
        case legal = "Legal"
        case international = "International"
        case nonprofit = "Non-Profit"
        
        var icon: String {
            switch self {
            case .academic: return "graduationcap.fill"
            case .government: return "building.columns.fill"
            case .news: return "newspaper.fill"
            case .factCheck: return "checkmark.shield.fill"
            case .research: return "flask.fill"
            case .medical: return "cross.fill"
            case .legal: return "scale.3d"
            case .international: return "globe"
            case .nonprofit: return "heart.fill"
            }
        }
        
        var color: String {
            switch self {
            case .academic: return "blue"
            case .government: return "purple"
            case .news: return "orange"
            case .factCheck: return "green"
            case .research: return "cyan"
            case .medical: return "red"
            case .legal: return "indigo"
            case .international: return "teal"
            case .nonprofit: return "pink"
            }
        }
        
        var trustMultiplier: Double {
            switch self {
            case .academic, .government, .medical: return 1.0
            case .factCheck, .research: return 0.95
            case .legal, .international: return 0.9
            case .news: return 0.8
            case .nonprofit: return 0.75
            }
        }
    }
    
    var credibilityLevel: CredibilityLevel {
        switch credibilityScore {
        case 0.9...1.0: return .veryHigh
        case 0.8..<0.9: return .high
        case 0.6..<0.8: return .medium
        case 0.4..<0.6: return .low
        default: return .veryLow
        }
    }
    
    enum CredibilityLevel: String, CaseIterable {
        case veryHigh = "Very High"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case veryLow = "Very Low"
        
        var color: String {
            switch self {
            case .veryHigh: return "green"
            case .high: return "mint"
            case .medium: return "yellow"
            case .low: return "orange"
            case .veryLow: return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .veryHigh: return "star.fill"
            case .high: return "star.leadinghalf.filled"
            case .medium: return "star"
            case .low: return "star.slash"
            case .veryLow: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    var adjustedCredibility: Double {
        credibilityScore * sourceType.trustMultiplier
    }
    
    var isRecent: Bool {
        guard let publishDate = publishDate else { return false }
        return Date().timeIntervalSince(publishDate) < 86400 * 30 // 30 days
    }
    
    var displayTitle: String {
        title.count > 100 ? String(title.prefix(97)) + "..." : title
    }
}

// MARK: - API Response Models

struct NewsAPIResponse: Codable {
    let articles: [NewsArticle]
    let totalResults: Int
    let status: String
}

struct NewsArticle: Codable {
    let title: String
    let description: String?
    let url: String
    let publishedAt: String
    let author: String?
    let source: NewsSource
}

struct NewsSource: Codable {
    let name: String
}

struct SemanticScholarResponse: Codable {
    let data: [ScholarPaper]
    let total: Int
}

struct ScholarPaper: Codable {
    let title: String
    let abstract: String?
    let url: String?
    let authors: [ScholarAuthor]
    let publicationDate: String?
    let citationCount: Int?
}

struct ScholarAuthor: Codable {
    let name: String
}

struct FactCheckAPIResponse: Codable {
    let claims: [FactCheckClaim]
}

struct FactCheckClaim: Codable {
    let text: String
    let claimReview: [ClaimReview]
}

struct ClaimReview: Codable {
    let publisher: ClaimPublisher
    let url: String?
    let title: String?
    let reviewDate: String?
    let textualRating: String?
}

struct ClaimPublisher: Codable {
    let name: String
    let site: String?
}

struct GoogleSearchResponse: Codable {
    let items: [SearchItem]
}

struct SearchItem: Codable {
    let title: String
    let link: String
    let snippet: String
}

struct GovernmentAPI {
    let name: String
    let baseURL: String
    let credibility: Double
}
