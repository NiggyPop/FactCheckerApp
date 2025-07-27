//
//  FactCheckCoordinator.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import Combine

class FactCheckCoordinator: ObservableObject {
    @Published var activeFactChecks: [UUID: FactCheckResult] = [:]
    @Published var factCheckHistory: [FactCheckResult] = []
    @Published var isProcessing = false
    
    private let speechService: SpeechRecognitionService
    private let speakerService: SpeakerIdentificationService
    private let factCheckService: EnhancedFactCheckingService
    private let databaseService = DatabaseService()
    
    private var cancellables = Set<AnyCancellable>()
    
    init(speechService: SpeechRecognitionService, 
         speakerService: SpeakerIdentificationService, 
         factCheckService: EnhancedFactCheckingService) {
        self.speechService = speechService
        self.speakerService = speakerService
        self.factCheckService = factCheckService
        
        setupSubscriptions()
        loadFactCheckHistory()
    }
    
    private func setupSubscriptions() {
        // Listen for new content from speech recognition
        speechService.newContentPublisher
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] content in
                self?.processNewContent(content)
            }
            .store(in: &cancellables)
        
        // Listen for speaker identification updates
        speakerService.$currentSpeaker
            .sink { [weak self] speakerId in
                self?.updateCurrentSpeaker(speakerId)
            }
            .store(in: &cancellables)
    }
    
    private func processNewContent(_ content: String) {
        guard !content.isEmpty else { return }
        
        let currentSpeaker = speakerService.currentSpeaker
        let factCheckId = UUID()
        
        isProcessing = true
        
        factCheckService.checkStatement(content, speakerId: currentSpeaker)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handleFactCheckResult(result, id: factCheckId)
            }
            .store(in: &cancellables)
    }
    
    private func handleFactCheckResult(_ result: FactCheckResult, id: UUID) {
        activeFactChecks[id] = result
        factCheckHistory.insert(result, at: 0)
        
        // Update speaker statistics
        speakerService.updateSpeakerStats(speakerId: result.speakerId, truthLabel: result.truthLabel)
        
        // Save to database
        databaseService.saveFactCheckResult(result)
        
        isProcessing = false
        
        // Remove from active checks after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            self.activeFactChecks.removeValue(forKey: id)
        }
    }
    
    private func updateCurrentSpeaker(_ speakerId: String) {
        // Handle speaker changes if needed
    }
    
    func startFactChecking() {
        speechService.startListening()
        speakerService.startListening(to: speechService.audioDataPublisher)
    }
    
    func stopFactChecking() {
        speechService.stopListening()
        isProcessing = false
    }
    
    func clearHistory() {
        factCheckHistory.removeAll()
        databaseService.clearFactCheckHistory()
    }
    
    func exportHistory() -> Data? {
        return try? JSONEncoder().encode(factCheckHistory)
    }
    
    private func loadFactCheckHistory() {
        factCheckHistory = databaseService.loadFactCheckHistory()
    }
    
    // MARK: - Statistics
    
    var totalFactChecks: Int {
        factCheckHistory.count
    }
    
    var accuracyRate: Double {
        let trueCount = factCheckHistory.filter { 
            $0.truthLabel == .true || $0.truthLabel == .likelyTrue 
        }.count
        guard totalFactChecks > 0 else { return 0.0 }
        return Double(trueCount) / Double(totalFactChecks)
    }
    
    var averageConfidence: Double {
        guard !factCheckHistory.isEmpty else { return 0.0 }
        return factCheckHistory.reduce(0.0) { $0 + $1.confidence } / Double(factCheckHistory.count)
    }
    
    func getStatistics(for timeframe: StatisticsTimeframe) -> FactCheckStatistics {
        let filteredResults = factCheckHistory.filter { result in
            let timeInterval = Date().timeIntervalSince(result.timestamp)
            return timeInterval <= timeframe.seconds
        }
        
        return FactCheckStatistics(
            totalChecks: filteredResults.count,
            trueCount: filteredResults.filter { $0.truthLabel == .true }.count,
            falseCount: filteredResults.filter { $0.truthLabel == .false }.count,
            mixedCount: filteredResults.filter { $0.truthLabel == .mixed }.count,
            unknownCount: filteredResults.filter { $0.truthLabel == .unknown }.count,
            averageConfidence: filteredResults.isEmpty ? 0.0 : 
                filteredResults.reduce(0.0) { $0 + $1.confidence } / Double(filteredResults.count),
            topSources: getTopSources(from: filteredResults),
            claimTypeDistribution: getClaimTypeDistribution(from: filteredResults)
        )
    }
    
    private func getTopSources(from results: [FactCheckResult]) -> [String] {
        let allSources = results.flatMap { $0.sources }
        let sourceCounts = Dictionary(grouping: allSources) { $0.domain }
            .mapValues { $0.count }
        
        return sourceCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    private func getClaimTypeDistribution(from results: [FactCheckResult]) -> [ClaimType: Int] {
        return Dictionary(grouping: results) { $0.claimType }
            .mapValues { $0.count }
    }
}

// MARK: - Supporting Types

enum StatisticsTimeframe: CaseIterable {
    case hour
    case day
    case week
    case month
    case year
    case all
    
    var seconds: TimeInterval {
        switch self {
        case .hour: return 3600
        case .day: return 86400
        case .week: return 604800
        case .month: return 2592000
        case .year: return 31536000
        case .all: return .greatestFiniteMagnitude
        }
    }
    
    var displayName: String {
        switch self {
        case .hour: return "Last Hour"
        case .day: return "Last Day"
        case .week: return "Last Week"
        case .month: return "Last Month"
        case .year: return "Last Year"
        case .all: return "All Time"
        }
    }
}

struct FactCheckStatistics {
    let totalChecks: Int
    let trueCount: Int
    let falseCount: Int
    let mixedCount: Int
    let unknownCount: Int
    let averageConfidence: Double
    let topSources: [String]
    let claimTypeDistribution: [ClaimType: Int]
    
    var accuracyRate: Double {
        guard totalChecks > 0 else { return 0.0 }
        return Double(trueCount) / Double(totalChecks)
    }
    
    var verificationRate: Double {
        guard totalChecks > 0 else { return 0.0 }
        let verifiedCount = trueCount + falseCount + mixedCount
        return Double(verifiedCount) / Double(totalChecks)
    }
}
