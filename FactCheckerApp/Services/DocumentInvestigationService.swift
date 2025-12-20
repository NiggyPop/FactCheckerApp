//
//  DocumentInvestigationService.swift
//  FactCheckerApp
//
//  Created by OpenAI Assistant on 7/13/24.
//

import Foundation
import NaturalLanguage

class DocumentInvestigationService {
    private let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    private let knownFigures: [String: String] = [
        "Joe Biden": "US President",
        "Kamala Harris": "US Vice President",
        "Donald Trump": "Former US President",
        "Elon Musk": "Business Leader",
        "Jeff Bezos": "Business Leader",
        "Barack Obama": "Former US President",
        "Janet Yellen": "Treasury Secretary"
    ]
    
    func processDocuments(at urls: [URL]) async -> [InvestigatedDocument] {
        var processed: [InvestigatedDocument] = []
        
        for url in urls {
            guard let document = processSingleDocument(url) else { continue }
            processed.append(document)
        }
        
        return processed
    }
    
    private func processSingleDocument(_ url: URL) -> InvestigatedDocument? {
        let text = extractText(from: url)
        let figures = identifyFigures(in: text)
        let connections = identifyConnections(in: text, figures: figures)
        let events = buildTimeline(from: text, fileName: url.lastPathComponent, figures: figures.map { $0.name })
        let preview = String(text.prefix(240))
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
        
        return InvestigatedDocument(
            url: url,
            fileName: url.lastPathComponent,
            fileSize: size,
            importedAt: Date(),
            textPreview: preview,
            detectedFigures: figures,
            connections: connections,
            events: events
        )
    }
    
    private func extractText(from url: URL) -> String {
        if let content = try? String(contentsOf: url) {
            return content
        }
        
        return "No readable text found in \(url.lastPathComponent). Add notes to help extract relevant details."
    }
    
    private func identifyFigures(in text: String) -> [PublicFigure] {
        var figures: [PublicFigure] = []
        
        for (name, role) in knownFigures {
            let mentions = text.components(separatedBy: name).count - 1
            if mentions > 0 {
                figures.append(PublicFigure(
                    name: name,
                    role: role,
                    confidence: min(1.0, Double(mentions) * 0.15 + 0.5),
                    mentions: mentions,
                    relatedEntities: collectRelatedEntities(around: name, in: text)
                ))
            }
        }
        
        // Fallback heuristic for capitalized phrases that look like names
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var candidate = ""
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            if word.count > 2, word.first?.isUppercase == true {
                candidate.append(candidate.isEmpty ? word : " \(word)")
            } else if !candidate.isEmpty {
                if candidate.split(separator: " ").count >= 2 {
                    figures.append(PublicFigure(
                        name: candidate,
                        role: "Mentioned Figure",
                        confidence: 0.35,
                        mentions: 1,
                        relatedEntities: []
                    ))
                }
                candidate = ""
            }
            return true
        }
        if !candidate.isEmpty, candidate.split(separator: " ").count >= 2 {
            figures.append(PublicFigure(
                name: candidate,
                role: "Mentioned Figure",
                confidence: 0.35,
                mentions: 1,
                relatedEntities: []
            ))
        }
        
        let uniqueFigures = Array(Set(figures))
        return uniqueFigures
    }
    
    private func collectRelatedEntities(around name: String, in text: String) -> [String] {
        guard let range = text.range(of: name) else { return [] }
        let lower = text.index(range.lowerBound, offsetBy: -120, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: 120, limitedBy: text.endIndex) ?? text.endIndex
        let context = text[lower...upper]
        let keywords = ["LLC", "Inc", "Foundation", "Committee", "Property", "Estate", "Realty", "Bank", "Holding"]
        return keywords.filter { context.localizedCaseInsensitiveContains($0) }
    }
    
    private func identifyConnections(in text: String, figures: [PublicFigure]) -> [ConnectionInsight] {
        var connections: [ConnectionInsight] = []
        let lower = text.lowercased()
        
        if lower.contains("property") || lower.contains("real estate") || lower.contains("mortgage") {
            connections.append(ConnectionInsight(
                title: "Real estate involvement",
                detail: "Detected references to property or real estate agreements.",
                confidence: 0.72,
                relatedFigures: figures.map { $0.name },
                type: .realEstate
            ))
        }
        
        if lower.contains("donation") || lower.contains("campaign") || lower.contains("committee") {
            connections.append(ConnectionInsight(
                title: "Political fundraising",
                detail: "Mentions of campaigns or committees suggest political ties.",
                confidence: 0.64,
                relatedFigures: figures.map { $0.name },
                type: .political
            ))
        }
        
        if lower.contains("loan") || lower.contains("bank") || lower.contains("financ") {
            connections.append(ConnectionInsight(
                title: "Financial arrangements",
                detail: "Loan or banking language indicates potential financial relationships.",
                confidence: 0.58,
                relatedFigures: figures.map { $0.name },
                type: .financial
            ))
        }
        
        if lower.contains("agreement") || lower.contains("contract") || lower.contains("deal") {
            connections.append(ConnectionInsight(
                title: "Contractual activity",
                detail: "Contracts or deals identified that may link multiple parties.",
                confidence: 0.55,
                relatedFigures: figures.map { $0.name },
                type: .business
            ))
        }
        
        if connections.isEmpty {
            connections.append(ConnectionInsight(
                title: "Context only",
                detail: "No explicit ties found; consider adding notes for clarity.",
                confidence: 0.35,
                relatedFigures: figures.map { $0.name },
                type: .other
            ))
        }
        
        return connections
    }
    
    private func buildTimeline(from text: String, fileName: String, figures: [String]) -> [TimelineEvent] {
        guard let dateDetector else { return defaultEvent(for: fileName, figures: figures) }
        let range = NSRange(location: 0, length: (text as NSString).length)
        let matches = dateDetector.matches(in: text, options: [], range: range)
        
        let events: [TimelineEvent] = matches.compactMap { match in
            guard let date = match.date else { return nil }
            let snippetRange = Range(match.range, in: text) ?? text.startIndex..<text.endIndex
            let snippet = String(text[snippetRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return TimelineEvent(
                date: date,
                title: "Referenced date",
                context: snippet.isEmpty ? "Date referenced in \(fileName)" : snippet,
                linkedFigures: figures,
                sourceFile: fileName,
                relevanceScore: 0.5
            )
        }
        
        if events.isEmpty {
            return defaultEvent(for: fileName, figures: figures)
        }
        
        return events
    }
    
    private func defaultEvent(for fileName: String, figures: [String]) -> [TimelineEvent] {
        return [
            TimelineEvent(
                date: Date(),
                title: "Document added",
                context: "Imported \(fileName) for analysis.",
                linkedFigures: figures,
                sourceFile: fileName,
                relevanceScore: 0.3
            )
        ]
    }
}
