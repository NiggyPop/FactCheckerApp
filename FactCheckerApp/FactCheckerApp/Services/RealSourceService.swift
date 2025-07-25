//
//  RealSourceService.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation

class RealSourceService {
    private let urlSession = URLSession.shared
    private let apiKeys = APIKeys.shared
    
    // MARK: - News API
    
    func searchNews(query: String) async throws -> [RealTimeSource] {
        guard let apiKey = apiKeys.newsAPIKey else {
            throw APIError.missingAPIKey("News API")
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://newsapi.org/v2/everything?q=\(encodedQuery)&sortBy=relevancy&pageSize=20&apiKey=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, _) = try await urlSession.data(from: url)
        let response = try JSONDecoder().decode(NewsAPIResponse.self, from: data)
        
        return response.articles.compactMap { article in
            guard let url = URL(string: article.url) else { return nil }
            
            return RealTimeSource(
                title: article.title,
                url: article.url,
                domain: url.host ?? "",
                credibilityScore: calculateNewsCredibility(domain: url.host ?? ""),
                lastUpdated: parseNewsDate(article.publishedAt) ?? Date(),
                relevanceScore: 0.8,
                sourceType: .news,
                excerpt: article.description,
                author: article.author,
                publishDate: parseNewsDate(article.publishedAt),
                language: "en",
                country: "US"
            )
        }
    }
    
    // MARK: - Academic Sources
    
    func searchAcademic(query: String) async throws -> [RealTimeSource] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.semanticscholar.org/graph/v1/paper/search?query=\(encodedQuery)&limit=20&fields=title,abstract,url,authors,publicationDate,citationCount"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, _) = try await urlSession.data(from: url)
        let response = try JSONDecoder().decode(SemanticScholarResponse.self, from: data)
        
        return response.data.compactMap { paper in
            guard let paperUrl = paper.url else { return nil }
            
            let citationScore = min(1.0, Double(paper.citationCount ?? 0) / 100.0)
            
            return RealTimeSource(
                title: paper.title,
                url: paperUrl,
                domain: "semanticscholar.org",
                credibilityScore: 0.9 + (citationScore * 0.1),
                lastUpdated: parseAcademicDate(paper.publicationDate) ?? Date(),
                relevanceScore: 0.9,
                sourceType: .academic,
                excerpt: paper.abstract,
                author: paper.authors.first?.name,
                publishDate: parseAcademicDate(paper.publicationDate),
                language: "en",
                country: nil
            )
        }
    }
    
    // MARK: - Fact Checkers
    
    func searchFactCheckers(query: String) async throws -> [RealTimeSource] {
        guard let apiKey = apiKeys.googleFactCheckAPIKey else {
            throw APIError.missingAPIKey("Google Fact Check API")
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://factchecktools.googleapis.com/v1alpha1/claims:search?query=\(encodedQuery)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, _) = try await urlSession.data(from: url)
        let response = try JSONDecoder().decode(FactCheckAPIResponse.self, from: data)
        
        return response.claims.flatMap { claim in
            claim.claimReview.compactMap { review in
                guard let reviewUrl = review.url else { return nil }
                
                return RealTimeSource(
                    title: review.title ?? claim.text,
                    url: reviewUrl,
                    domain: review.publisher.site ?? review.publisher.name,
                    credibilityScore: calculateFactCheckerCredibility(publisher: review.publisher.name),
                    lastUpdated: parseFactCheckDate(review.reviewDate) ?? Date(),
                    relevanceScore: 0.95,
                    sourceType: .factCheck,
                    excerpt: review.textualRating,
                    author: review.publisher.name,
                    publishDate: parseFactCheckDate(review.reviewDate),
                    language: "en",
                    country: nil
                )
            }
        }
    }
    
    // MARK: - Government Sources
    
    func searchGovernment(query: String) async throws -> [RealTimeSource] {
        var sources: [RealTimeSource] = []
        
        // Search multiple government APIs
        async let cdcResults = searchCDC(query: query)
        async let censusResults = searchCensus(query: query)
        async let nihResults = searchNIH(query: query)
        async let govResults = searchGovData(query: query)
        
        let allResults = try await [
            cdcResults,
            censusResults,
            nihResults,
            govResults
        ]
        
        return allResults.flatMap { $0 }
    }
    
    private func searchCDC(query: String) async throws -> [RealTimeSource] {
        // CDC API search (simplified)
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://tools.cdc.gov/api/v2/resources/media?q=\(encodedQuery)&max=10"
        
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await urlSession.data(from: url)
            // Parse CDC response (implementation depends on actual API structure)
            return [] // Placeholder
        } catch {
            return []
        }
    }
    
    private func searchCensus(query: String) async throws -> [RealTimeSource] {
        // Census API search (simplified)
        return []
    }
    
    private func searchNIH(query: String) async throws -> [RealTimeSource] {
        // NIH PubMed search
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=\(encodedQuery)&retmax=10&retmode=json"
        
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await urlSession.data(from: url)
            // Parse PubMed response and fetch details
            return []
        } catch {
            return []
        }
    }
    
    private func searchGovData(query: String) async throws -> [RealTimeSource] {
        // Data.gov search
        return []
    }
    
    // MARK: - Credibility Scoring
    
    private func calculateNewsCredibility(domain: String) -> Double {
        let highCredibilityDomains = [
            "reuters.com": 0.95,
            "apnews.com": 0.95,
            "bbc.com": 0.9,
            "npr.org": 0.9,
            "pbs.org": 0.9,
            "wsj.com": 0.85,
            "nytimes.com": 0.85,
            "washingtonpost.com": 0.85,
            "theguardian.com": 0.8,
            "cnn.com": 0.75,
            "abcnews.go.com": 0.75,
            "cbsnews.com": 0.75,
            "nbcnews.com": 0.75
        ]
        
        let mediumCredibilityDomains = [
            "usatoday.com": 0.7,
            "time.com": 0.7,
            "newsweek.com": 0.65,
            "politico.com": 0.7,
            "axios.com": 0.75
        ]
        
        let lowCredibilityDomains = [
            "dailymail.co.uk": 0.4,
            "nypost.com": 0.5,
            "foxnews.com": 0.6
        ]
        
        if let score = highCredibilityDomains[domain] {
            return score
        } else if let score = mediumCredibilityDomains[domain] {
            return score
        } else if let score = lowCredibilityDomains[domain] {
            return score
        }
        
        // Default scoring based on domain characteristics
        if domain.contains(".gov") {
            return 0.95
        } else if domain.contains(".edu") {
            return 0.9
        } else if domain.contains(".org") {
            return 0.75
        } else {
            return 0.6 // Unknown domain
        }
    }
    
    private func calculateFactCheckerCredibility(publisher: String) -> Double {
        let factCheckerCredibility = [
            "Snopes": 0.9,
            "PolitiFact": 0.9,
            "FactCheck.org": 0.95,
            "AP Fact Check": 0.95,
            "Reuters Fact Check": 0.95,
            "BBC Reality Check": 0.9,
            "Washington Post Fact Checker": 0.85,
            "CNN Fact Check": 0.8,
            "USA Today Fact Check": 0.8,
            "Lead Stories": 0.85,
            "Check Your Fact": 0.8,
            "Truth or Fiction": 0.75
        ]
        
        return factCheckerCredibility[publisher] ?? 0.7
    }
    
    // MARK: - Date Parsing
    
    private func parseNewsDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    private func parseAcademicDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatters = [
            DateFormatter().then { $0.dateFormat = "yyyy-MM-dd" },
            DateFormatter().then { $0.dateFormat = "yyyy" }
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func parseFactCheckDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
}

// MARK: - API Error Handling

enum APIError: Error, LocalizedError {
    case missingAPIKey(String)
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case rateLimitExceeded
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let service):
            return "Missing API key for \(service)"
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .unauthorized:
            return "Unauthorized API access"
        }
    }
}

// MARK: - Helper Extension

extension DateFormatter {
    func then(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}
