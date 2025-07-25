//
//  EnhancedFactCheckingService.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import Combine

class EnhancedFactCheckingService: ObservableObject {
    @Published var isChecking = false
    @Published var lastResult: FactCheckResult?
    @Published var error: Error?
    
    private let urlSession = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    private let realSourceService = RealSourceService()
    
    func checkStatement(_ statement: String, speakerId: String) -> AnyPublisher<FactCheckResult, Never> {
        isChecking = true
        
        return Future<FactCheckResult, Never> { [weak self] promise in
            Task {
                do {
                    let result = try await self?.performComprehensiveFactCheck(statement, speakerId: speakerId)
                    DispatchQueue.main.async {
                        self?.isChecking = false
                        self?.lastResult = result
                        promise(.success(result ?? self?.createUnknownResult(statement, speakerId: speakerId) ?? FactCheckResult(
                            timestamp: Date(),
                            speakerId: speakerId,
                            statement: statement,
                            confidence: 0.0,
                            truthLabel: .unknown,
                            truthScore: 0.0,
                            sources: [],
                            explanation: "Unable to verify",
                            claimType: .general,
                            keyEntities: [],
                            sentiment: 0.0
                        )))
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.isChecking = false
                        self?.error = error
                        promise(.success(self?.createErrorResult(statement, speakerId: speakerId, error: error) ?? FactCheckResult(
                            timestamp: Date(),
                            speakerId: speakerId,
                            statement: statement,
                            confidence: 0.0,
                            truthLabel: .unknown,
                            truthScore: 0.0,
                            sources: [],
                            explanation: "Error occurred during verification",
                            claimType: .general,
                            keyEntities: [],
                            sentiment: 0.0
                        )))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func performComprehensiveFactCheck(_ statement: String, speakerId: String) async throws -> FactCheckResult {
        // Extract key entities and determine claim type
        let keyEntities = extractKeyEntities(from: statement)
        let claimType = determineClaimType(statement)
        let sentiment = analyzeSentiment(statement)
        
        // Gather sources from multiple APIs
        async let newsResults = realSourceService.searchNews(query: statement)
        async let academicResults = realSourceService.searchAcademic(query: statement)
        async let factCheckResults = realSourceService.searchFactCheckers(query: statement)
        async let governmentResults = realSourceService.searchGovernment(query: statement)
        
        let allSources = try await [
            newsResults,
            academicResults,
            factCheckResults,
            governmentResults
        ].flatMap { $0 }
        
        // Analyze and score the claim
        let analysis = analyzeClaimAgainstSources(statement, sources: allSources)
        
        return FactCheckResult(
            timestamp: Date(),
            speakerId: speakerId,
            statement: statement,
            confidence: analysis.confidence,
            truthLabel: analysis.truthLabel,
            truthScore: analysis.truthScore,
            sources: allSources.sorted { $0.credibilityScore > $1.credibilityScore },
            explanation: analysis.explanation,
            claimType: claimType,
            keyEntities: keyEntities,
            sentiment: sentiment
        )
    }
    
    private func extractKeyEntities(from text: String) -> [String] {
        // Simplified entity extraction
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var entities: [String] = []
        
        // Look for numbers, dates, proper nouns, etc.
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            
            // Numbers and percentages
            if cleanWord.contains("%") || Double(cleanWord) != nil {
                entities.append(cleanWord)
            }
            
            // Capitalized words (potential proper nouns)
            if cleanWord.first?.isUppercase == true && cleanWord.count > 2 {
                entities.append(cleanWord)
            }
            
            // Years
            if let year = Int(cleanWord), year > 1900 && year <= 2030 {
                entities.append(cleanWord)
            }
        }
        
        return Array(Set(entities)).prefix(10).map { String($0) }
    }
    
    private func determineClaimType(_ statement: String) -> ClaimType {
        let lowercased = statement.lowercased()
        
        if lowercased.contains("percent") || lowercased.contains("%") || lowercased.contains("statistics") {
            return .statistical
        } else if lowercased.contains("health") || lowercased.contains("medical") || lowercased.contains("disease") {
            return .medical
        } else if lowercased.contains("study") || lowercased.contains("research") || lowercased.contains("science") {
            return .scientific
        } else if lowercased.contains("president") || lowercased.contains("government") || lowercased.contains("policy") {
            return .political
        } else if lowercased.contains("economy") || lowercased.contains("dollar") || lowercased.contains("market") {
            return .economic
        } else if lowercased.contains("law") || lowercased.contains("court") || lowercased.contains("legal") {
            return .legal
        } else if lowercased.contains("climate") || lowercased.contains("environment") || lowercased.contains("pollution") {
            return .environmental
        } else if statement.contains("19") || statement.contains("20") {
            return .historical
        }
        
        return .general
    }
    
    private func analyzeSentiment(_ text: String) -> Double {
        // Simplified sentiment analysis
        let positiveWords = ["good", "great", "excellent", "positive", "beneficial", "helpful"]
        let negativeWords = ["bad", "terrible", "awful", "negative", "harmful", "dangerous"]
        
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let positiveCount = words.filter { positiveWords.contains($0) }.count
        let negativeCount = words.filter { negativeWords.contains($0) }.count
        
        let totalSentimentWords = positiveCount + negativeCount
        guard totalSentimentWords > 0 else { return 0.0 }
        
        return (Double(positiveCount) - Double(negativeCount)) / Double(totalSentimentWords)
    }
    
    private func analyzeClaimAgainstSources(_ claim: String, sources: [RealTimeSource]) -> (truthLabel: FactCheckResult.TruthLabel, truthScore: Double, confidence: Double, explanation: String) {
        
        guard !sources.isEmpty else {
            return (.unknown, 0.0, 0.0, "No sources found to verify this claim.")
        }
        
        // Weight sources by credibility
        let weightedSources = sources.filter { $0.credibilityScore > 0.5 }
        guard !weightedSources.isEmpty else {
            return (.unverifiable, 0.0, 0.3, "Available sources have low credibility scores.")
        }
        
        // Analyze source content for supporting/contradicting evidence
        var supportingEvidence: Double = 0.0
        var contradictingEvidence: Double = 0.0
        var totalWeight: Double = 0.0
        
        for source in weightedSources.prefix(10) { // Limit to top 10 sources
            let relevance = calculateRelevance(claim: claim, source: source)
            let weight = source.adjustedCredibility * relevance
            
            if let excerpt = source.excerpt {
                let support = calculateSupport(claim: claim, text: excerpt)
                if support > 0.6 {
                    supportingEvidence += weight * support
                } else if support < 0.4 {
                    contradictingEvidence += weight * (1.0 - support)
                }
            }
            
            totalWeight += weight
        }
        
        guard totalWeight > 0 else {
            return (.unknown, 0.0, 0.2, "Unable to analyze source content.")
        }
        
        let supportRatio = supportingEvidence / totalWeight
        let contradictRatio = contradictingEvidence / totalWeight
        let netSupport = supportRatio - contradictRatio
        
        // Determine truth label and score
        let truthScore = max(0.0, min(1.0, (netSupport + 1.0) / 2.0))
        let confidence = min(0.95, totalWeight / Double(weightedSources.count))
        
        let truthLabel: FactCheckResult.TruthLabel
        let explanation: String
        
        if netSupport > 0.6 {
            truthLabel = .true
            explanation = "Multiple high-credibility sources support this claim."
        } else if netSupport > 0.2 {
            truthLabel = .likelyTrue
            explanation = "Most sources tend to support this claim."
        } else if netSupport > -0.2 {
            truthLabel = .mixed
            explanation = "Sources show mixed evidence for this claim."
        } else if netSupport > -0.6 {
            truthLabel = .likelyFalse
            explanation = "Most sources tend to contradict this claim."
        } else {
            truthLabel = .false
            explanation = "Multiple high-credibility sources contradict this claim."
        }
        
        return (truthLabel, truthScore, confidence, explanation)
    }
    
    private func calculateRelevance(claim: String, source: RealTimeSource) -> Double {
        let claimWords = Set(claim.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })
        let titleWords = Set(source.title.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })
        let excerptWords = Set((source.excerpt ?? "").lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })
        
        let titleOverlap = Double(claimWords.intersection(titleWords).count) / Double(max(claimWords.count, 1))
        let excerptOverlap = Double(claimWords.intersection(excerptWords).count) / Double(max(claimWords.count, 1))
        
        return max(titleOverlap, excerptOverlap * 0.7)
    }
    
    private func calculateSupport(claim: String, text: String) -> Double {
        // Simplified support calculation based on keyword matching and sentiment
        let claimWords = Set(claim.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let textWords = Set(text.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let overlap = Double(claimWords.intersection(textWords).count) / Double(max(claimWords.count, 1))
        
        // Look for supporting/contradicting language
        let supportingPhrases = ["confirms", "supports", "evidence shows", "research indicates", "studies prove"]
        let contradictingPhrases = ["contradicts", "disproves", "false", "incorrect", "no evidence"]
        
        let textLower = text.lowercased()
        let hasSupporting = supportingPhrases.contains { textLower.contains($0) }
        let hasContradicting = contradictingPhrases.contains { textLower.contains($0) }
        
        var support = overlap
        if hasSupporting { support += 0.3 }
        if hasContradicting { support -= 0.3 }
        
        return max(0.0, min(1.0, support))
    }
    
    private func createUnknownResult(_ statement: String, speakerId: String) -> FactCheckResult {
        return FactCheckResult(
            timestamp: Date(),
            speakerId: speakerId,
            statement: statement,
            confidence: 0.0,
            truthLabel: .unknown,
            truthScore: 0.0,
            sources: [],
            explanation: "Unable to find sufficient sources to verify this claim.",
            claimType: determineClaimType(statement),
            keyEntities: extractKeyEntities(from: statement),
            sentiment: analyzeSentiment(statement)
        )
    }
    
    private func createErrorResult(_ statement: String, speakerId: String, error: Error) -> FactCheckResult {
        return FactCheckResult(
            timestamp: Date(),
            speakerId: speakerId,
            statement: statement,
            confidence: 0.0,
            truthLabel: .unknown,
            truthScore: 0.0,
            sources: [],
            explanation: "An error occurred while verifying this claim: \(error.localizedDescription)",
            claimType: determineClaimType(statement),
            keyEntities: extractKeyEntities(from: statement),
            sentiment: analyzeSentiment(statement)
        )
    }
}
