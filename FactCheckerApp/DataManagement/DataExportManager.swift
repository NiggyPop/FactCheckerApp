//
//  DataExportManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import Combine
import UniformTypeIdentifiers

class DataExportManager: ObservableObject {
    private let dataManager: DataManager
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    // MARK: - Export Methods
    
    func exportData(format: ExportFormat, dateRange: DateRange? = nil) -> AnyPublisher<URL, ExportError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown))
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.performExport(format: format, dateRange: dateRange, completion: promise)
            }
        }
        .receive(on: DispatchQueue.main)
        .handleEvents(
            receiveSubscription: { _ in
                self.isExporting = true
                self.exportProgress = 0.0
            },
            receiveCompletion: { _ in
                self.isExporting = false
                self.exportProgress = 0.0
            }
        )
        .eraseToAnyPublisher()
    }
    
    private func performExport(format: ExportFormat, dateRange: DateRange?, completion: @escaping (Result<URL, ExportError>) -> Void) {
        do {
            // Fetch data
            updateProgress(0.1)
            let results = try fetchDataForExport(dateRange: dateRange)
            
            updateProgress(0.3)
            
            // Generate export file
            let exportURL = try generateExportFile(results: results, format: format)
            
            updateProgress(1.0)
            
            completion(.success(exportURL))
        } catch {
            completion(.failure(error as? ExportError ?? .unknown))
        }
    }
    
    private func fetchDataForExport(dateRange: DateRange?) throws -> [FactCheckResult] {
        let request = dataManager.createFetchRequest()
        
        if let dateRange = dateRange {
            let predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", dateRange.startDate as NSDate, dateRange.endDate as NSDate)
            request.predicate = predicate
        }
        
        return try dataManager.context.fetch(request)
    }
    
    private func generateExportFile(results: [FactCheckResult], format: ExportFormat) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "factcheck_export_\(Date().timeIntervalSince1970).\(format.fileExtension)"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        updateProgress(0.5)
        
        switch format {
        case .json:
            try exportAsJSON(results: results, to: fileURL)
        case .csv:
            try exportAsCSV(results: results, to: fileURL)
        case .pdf:
            try exportAsPDF(results: results, to: fileURL)
        }
        
        updateProgress(0.9)
        
        return fileURL
    }
    
    private func exportAsJSON(results: [FactCheckResult], to url: URL) throws {
        let exportData = ExportData(
            exportDate: Date(),
            version: AppConfig.appVersion,
            totalResults: results.count,
            results: results.map { ExportableFactCheckResult(from: $0) }
        )
        
        let jsonData = try JSONEncoder().encode(exportData)
        try jsonData.write(to: url)
    }
    
    private func exportAsCSV(results: [FactCheckResult], to url: URL) throws {
        var csvContent = "Date,Statement,Veracity,Confidence,Sources Count,Processing Time,Claim Type\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        for result in results {
            let escapedStatement = result.statement.replacingOccurrences(of: "\"", with: "\"\"")
            let row = "\"\(dateFormatter.string(from: result.timestamp))\",\"\(escapedStatement)\",\(result.veracity.rawValue),\(result.confidence),\(result.sources.count),\(result.processingTime),\(result.claimType.rawValue)\n"
            csvContent += row
        }
        
        try csvContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func exportAsPDF(results: [FactCheckResult], to url: URL) throws {
        let pdfGenerator = PDFGenerator()
        try pdfGenerator.generatePDF(results: results, outputURL: url)
    }
    
    private func updateProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.exportProgress = progress
        }
    }
}

// MARK: - Supporting Types

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case pdf = "PDF"
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .pdf: return "pdf"
        }
    }
    
    var utType: UTType {
        switch self {
        case .json: return .json
        case .csv: return .commaSeparatedText
        case .pdf: return .pdf
        }
    }
}

enum ExportError: Error, LocalizedError {
    case noData
    case fileCreationFailed
    case encodingFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return L("export_error_no_data")
        case .fileCreationFailed:
            return L("export_error_file_creation")
        case .encodingFailed:
            return L("export_error_encoding")
        case .unknown:
            return L("export_error_unknown")
        }
    }
}

struct DateRange {
    let startDate: Date
    let endDate: Date
}

struct ExportData: Codable {
    let exportDate: Date
    let version: String
    let totalResults: Int
    let results: [ExportableFactCheckResult]
}

struct ExportableFactCheckResult: Codable {
    let id: String
    let statement: String
    let veracity: String
    let confidence: Double
    let sources: [ExportableSource]
    let timestamp: Date
    let processingTime: Double
    let claimType: String
    
    init(from result: FactCheckResult) {
        self.id = result.id.uuidString
        self.statement = result.statement
        self.veracity = result.veracity.rawValue
        self.confidence = result.confidence
        self.sources = result.sources.map { ExportableSource(from: $0) }
        self.timestamp = result.timestamp
        self.processingTime = result.processingTime
        self.claimType = result.claimType.rawValue
    }
}

struct ExportableSource: Codable {
    let url: String
    let title: String
    let credibilityScore: Double
    let summary: String
    
    init(from source: FactCheckSource) {
        self.url = source.url
        self.title = source.title
        self.credibilityScore = source.credibilityScore
        self.summary = source.summary
    }
}
