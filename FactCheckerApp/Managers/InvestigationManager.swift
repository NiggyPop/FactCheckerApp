//
//  InvestigationManager.swift
//  FactCheckerApp
//
//  Created by OpenAI Assistant on 7/13/24.
//

import Foundation
import UniformTypeIdentifiers

@MainActor
class InvestigationManager: ObservableObject {
    @Published private(set) var documents: [InvestigatedDocument] = []
    @Published private(set) var aggregatedConnections: [ConnectionInsight] = []
    @Published private(set) var timeline: [TimelineEvent] = []
    @Published private(set) var detectedFigures: [PublicFigure] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private let service = DocumentInvestigationService()
    
    func importDocuments(from urls: [URL]) {
        Task {
            await analyze(urls: urls)
        }
    }
    
    func clear() {
        documents.removeAll()
        aggregatedConnections.removeAll()
        timeline.removeAll()
        detectedFigures.removeAll()
    }
    
    private func analyze(urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        
        let securedURLs: [(url: URL, started: Bool)] = urls.map { url in
            let started = url.startAccessingSecurityScopedResource()
            return (url, started)
        }
        
        let processed = await service.processDocuments(at: securedURLs.map { $0.url })
        documents.append(contentsOf: processed)
        recomputeAggregates()
        
        securedURLs.forEach { entry in
            if entry.started {
                entry.url.stopAccessingSecurityScopedResource()
            }
        }
        
        isProcessing = false
    }
    
    private func recomputeAggregates() {
        detectedFigures = Array(Set(documents.flatMap { $0.detectedFigures }))
        aggregatedConnections = mergeConnections(from: documents)
        timeline = documents.flatMap { $0.events }.sorted { $0.date < $1.date }
    }
    
    private func mergeConnections(from documents: [InvestigatedDocument]) -> [ConnectionInsight] {
        var grouped: [String: ConnectionInsight] = [:]
        
        documents.forEach { doc in
            doc.connections.forEach { connection in
                let key = "\(connection.title)-\(connection.type.rawValue)"
                if var existing = grouped[key] {
                    let combinedFigures = Array(Set(existing.relatedFigures + connection.relatedFigures))
                    existing = ConnectionInsight(
                        title: existing.title,
                        detail: connection.detail,
                        confidence: max(existing.confidence, connection.confidence),
                        relatedFigures: combinedFigures,
                        type: connection.type
                    )
                    grouped[key] = existing
                } else {
                    grouped[key] = connection
                }
            }
        }
        
        return Array(grouped.values).sorted { $0.confidence > $1.confidence }
    }
    
    var summary: InvestigationSummary {
        InvestigationSummary(
            documentsCount: documents.count,
            figureCount: detectedFigures.count,
            connectionCount: aggregatedConnections.count,
            eventCount: timeline.count
        )
    }
    
    var supportedTypes: [UTType] {
        var types: [UTType] = [.pdf, .plainText, .rtf, .text, .data, .item]
        if let utf8 = UTType("public.utf8-plain-text") {
            types.append(utf8)
        }
        return types
    }
}
