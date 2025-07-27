//
//  DatabaseService.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import SQLite3

class DatabaseService {
    private var db: OpaquePointer?
    private let dbPath: String
    
    init() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("FactChecker.sqlite")
        
        dbPath = fileURL.path
        openDatabase()
        createTables()
    }
    
    deinit {
        closeDatabase()
    }
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Unable to open database")
        }
    }
    
    private func closeDatabase() {
        if sqlite3_close(db) != SQLITE_OK {
            print("Unable to close database")
        }
    }
    
    private func createTables() {
        createFactCheckTable()
        createSpeakerTable()
        createSourceTable()
    }
    
    private func createFactCheckTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS fact_checks (
                id TEXT PRIMARY KEY,
                timestamp REAL,
                speaker_id TEXT,
                statement TEXT,
                confidence REAL,
                truth_label TEXT,
                truth_score REAL,
                explanation TEXT,
                claim_type TEXT,
                key_entities TEXT,
                sentiment REAL
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("Error creating fact_checks table")
        }
    }
    
    private func createSpeakerTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS speakers (
                id TEXT PRIMARY KEY,
                name TEXT,
                registration_date REAL,
                last_seen REAL,
                total_statements INTEGER,
                true_statements INTEGER,
                false_statements INTEGER,
                mixed_statements INTEGER,
                unknown_statements INTEGER,
                is_active INTEGER
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("Error creating speakers table")
        }
    }
    
    private func createSourceTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS sources (
                id TEXT PRIMARY KEY,
                fact_check_id TEXT,
                title TEXT,
                url TEXT,
                domain TEXT,
                credibility_score REAL,
                source_type TEXT,
                excerpt TEXT,
                author TEXT,
                publish_date REAL,
                FOREIGN KEY(fact_check_id) REFERENCES fact_checks(id)
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("Error creating sources table")
        }
    }
    
    // MARK: - Fact Check Operations
    
    func saveFactCheckResult(_ result: FactCheckResult) {
        let insertSQL = """
            INSERT INTO fact_checks 
            (id, timestamp, speaker_id, statement, confidence, truth_label, truth_score, explanation, claim_type, key_entities, sentiment)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, result.id.uuidString, -1, nil)
            sqlite3_bind_double(statement, 2, result.timestamp.timeIntervalSince1970)
            sqlite3_bind_text(statement, 3, result.speakerId, -1, nil)
            sqlite3_bind_text(statement, 4, result.statement, -1, nil)
            sqlite3_bind_double(statement, 5, result.confidence)
            sqlite3_bind_text(statement, 6, result.truthLabel.rawValue, -1, nil)
            sqlite3_bind_double(statement, 7, result.truthScore)
            sqlite3_bind_text(statement, 8, result.explanation, -1, nil)
            sqlite3_bind_text(statement, 9, result.claimType.rawValue, -1, nil)
            
            let entitiesJSON = try? JSONEncoder().encode(result.keyEntities)
            let entitiesString = entitiesJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            sqlite3_bind_text(statement, 10, entitiesString, -1, nil)
            
            sqlite3_bind_double(statement, 11, result.sentiment)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                // Save sources
                for source in result.sources {
                    saveSource(source, factCheckId: result.id.uuidString)
                }
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    private func saveSource(_ source: RealTimeSource, factCheckId: String) {
        let insertSQL = """
            INSERT INTO sources 
            (id, fact_check_id, title, url, domain, credibility_score, source_type, excerpt, author, publish_date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, source.id.uuidString, -1, nil)
            sqlite3_bind_text(statement, 2, factCheckId, -1, nil)
            sqlite3_bind_text(statement, 3, source.title, -1, nil)
            sqlite3_bind_text(statement, 4, source.url, -1, nil)
            sqlite3_bind_text(statement, 5, source.domain, -1, nil)
            sqlite3_bind_double(statement, 6, source.credibilityScore)
            sqlite3_bind_text(statement, 7, source.sourceType.rawValue, -1, nil)
            sqlite3_bind_text(statement, 8, source.excerpt, -1, nil)
            sqlite3_bind_text(statement, 9, source.author, -1, nil)
            
            if let publishDate = source.publishDate {
                sqlite3_bind_double(statement, 10, publishDate.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(statement, 10)
            }
            
            sqlite3_step(statement)
        }
        
        sqlite3_finalize(statement)
    }
    
    func loadFactCheckHistory() -> [FactCheckResult] {
        let querySQL = "SELECT * FROM fact_checks ORDER BY timestamp DESC LIMIT 1000;"
        var statement: OpaquePointer?
        var results: [FactCheckResult] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let result = parseFactCheckResult(from: statement) {
                    results.append(result)
                }
            }
        }
        
        sqlite3_finalize(statement)
        
        // Load sources for each result
        for i in 0..<results.count {
            results[i] = FactCheckResult(
                timestamp: results[i].timestamp,
                speakerId: results[i].speakerId,
                statement: results[i].statement,
                confidence: results[i].confidence,
                truthLabel: results[i].truthLabel,
                truthScore: results[i].truthScore,
                sources: loadSources(for: results[i].id.uuidString),
                explanation: results[i].explanation,
                claimType: results[i].claimType,
                keyEntities: results[i].keyEntities,
                sentiment: results[i].sentiment
            )
        }
        
        return results
    }
    
    private func parseFactCheckResult(from statement: OpaquePointer?) -> FactCheckResult? {
        guard let statement = statement else { return nil }
        
        let idString = String(cString: sqlite3_column_text(statement, 0))
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
        let speakerId = String(cString: sqlite3_column_text(statement, 2))
        let statementText = String(cString: sqlite3_column_text(statement, 3))
        let confidence = sqlite3_column_double(statement, 4)
        let truthLabelString = String(cString: sqlite3_column_text(statement, 5))
        let truthScore = sqlite3_column_double(statement, 6)
        let explanation = String(cString: sqlite3_column_text(statement, 7))
        let claimTypeString = String(cString: sqlite3_column_text(statement, 8))
        let entitiesString = String(cString: sqlite3_column_text(statement, 9))
        let sentiment = sqlite3_column_double(statement, 10)
        
        guard let id = UUID(uuidString: idString),
              let truthLabel = FactCheckResult.TruthLabel(rawValue: truthLabelString),
              let claimType = ClaimType(rawValue: claimTypeString) else {
            return nil
        }
        
        let keyEntities = (try? JSONDecoder().decode([String].self, from: entitiesString.data(using: .utf8) ?? Data())) ?? []
        
        return FactCheckResult(
            timestamp: timestamp,
            speakerId: speakerId,
            statement: statementText,
            confidence: confidence,
            truthLabel: truthLabel,
            truthScore: truthScore,
            sources: [], // Will be loaded separately
            explanation: explanation,
            claimType: claimType,
            keyEntities: keyEntities,
            sentiment: sentiment
        )
    }
    
    private func loadSources(for factCheckId: String) -> [RealTimeSource] {
        let querySQL = "SELECT * FROM sources WHERE fact_check_id = ?;"
        var statement: OpaquePointer?
        var sources: [RealTimeSource] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, factCheckId, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let source = parseSource(from: statement) {
                    sources.append(source)
                }
            }
        }
        
        sqlite3_finalize(statement)
        return sources
    }
    
    private func parseSource(from statement: OpaquePointer?) -> RealTimeSource? {
        guard let statement = statement else { return nil }
        
        let idString = String(cString: sqlite3_column_text(statement, 0))
        let title = String(cString: sqlite3_column_text(statement, 2))
        let url = String(cString: sqlite3_column_text(statement, 3))
        let domain = String(cString: sqlite3_column_text(statement, 4))
        let credibilityScore = sqlite3_column_double(statement, 5)
        let sourceTypeString = String(cString: sqlite3_column_text(statement, 6))
        let excerpt = sqlite3_column_type(statement, 7) != SQLITE_NULL ? String(cString: sqlite3_column_text(statement, 7)) : nil
        let author = sqlite3_column_type(statement, 8) != SQLITE_NULL ? String(cString: sqlite3_column_text(statement, 8)) : nil
        let publishDate = sqlite3_column_type(statement, 9) != SQLITE_NULL ? Date(timeIntervalSince1970: sqlite3_column_double(statement, 9)) : nil
        
        guard let id = UUID(uuidString: idString),
              let sourceType = RealTimeSource.SourceType(rawValue: sourceTypeString) else {
            return nil
        }
        
        return RealTimeSource(
            title: title,
            url: url,
            domain: domain,
            credibilityScore: credibilityScore,
            lastUpdated: Date(),
            relevanceScore: 0.8,
            sourceType: sourceType,
            excerpt: excerpt,
            author: author,
            publishDate: publishDate,
            language: "en",
            country: nil
        )
    }
    
    func clearFactCheckHistory() {
        let deleteSQL = "DELETE FROM fact_checks;"
        sqlite3_exec(db, deleteSQL, nil, nil, nil)
        
        let deleteSourcesSQL = "DELETE FROM sources;"
        sqlite3_exec(db, deleteSourcesSQL, nil, nil, nil)
    }
    
    // MARK: - Analytics
    
    func getFactCheckStatistics(timeframe: StatisticsTimeframe) -> FactCheckStatistics {
        let results = loadFactCheckHistory()
        let filteredResults = results.filter { result in
            let timeInterval = Date().timeIntervalSince(result.timestamp)
            return timeInterval <= timeframe.seconds
        }
        
        let trueCount = filteredResults.filter { $0.truthLabel == .true }.count
        let falseCount = filteredResults.filter { $0.truthLabel == .false }.count
        let mixedCount = filteredResults.filter { $0.truthLabel == .mixed }.count
        let unknownCount = filteredResults.filter { $0.truthLabel == .unknown }.count
        
        let averageConfidence = filteredResults.isEmpty ? 0.0 :
            filteredResults.reduce(0.0) { $0 + $1.confidence } / Double(filteredResults.count)
        
        let allSources = filteredResults.flatMap { $0.sources }
        let sourceCounts = Dictionary(grouping: allSources) { $0.domain }
            .mapValues { $0.count }
        let topSources = sourceCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
        
        let claimTypeDistribution = Dictionary(grouping: filteredResults) { $0.claimType }
            .mapValues { $0.count }
        
        return FactCheckStatistics(
            totalChecks: filteredResults.count,
            trueCount: trueCount,
            falseCount: falseCount,
            mixedCount: mixedCount,
            unknownCount: unknownCount,
            averageConfidence: averageConfidence,
            topSources: topSources,
            claimTypeDistribution: claimTypeDistribution
        )
    }
}
