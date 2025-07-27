//
//  ExportManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import AVFoundation
import UIKit

class ExportManager: ObservableObject {
    static let shared = ExportManager()
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0
    @Published var exportError: Error?
    
    private init() {}
    
    func exportRecording(
        _ recording: AudioFileInfo,
        format: AudioFileFormat,
        quality: ExportQuality,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        isExporting = true
        exportProgress = 0
        exportError = nil
        
        Task {
            do {
                let exportedURL = try await performExport(
                    recording: recording,
                    format: format,
                    quality: quality
                )
                
                await MainActor.run {
                    self.isExporting = false
                    completion(.success(exportedURL))
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.exportError = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func performExport(
        recording: AudioFileInfo,
        format: AudioFileFormat,
        quality: ExportQuality
    ) async throws -> URL {
        let outputURL = createExportURL(for: recording, format: format)
        
        let asset = AVAsset(url: recording.url)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: quality.presetName
        ) else {
            throw ExportError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = format.avFileType
        
        // Monitor progress
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.exportProgress = Double(exportSession.progress)
            }
        }
        
        await exportSession.export()
        progressTimer.invalidate()
        
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw exportSession.error ?? ExportError.exportFailed
        case .cancelled:
            throw ExportError.exportCancelled
        default:
            throw ExportError.unexpectedStatus
        }
    }
    
    func exportMultipleRecordings(
        _ recordings: [AudioFileInfo],
        format: AudioFileFormat,
        quality: ExportQuality,
        as exportType: MultipleExportType,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        isExporting = true
        exportProgress = 0
        exportError = nil
        
        Task {
            do {
                let result: URL
                
                switch exportType {
                case .individual:
                    result = try await exportIndividualFiles(recordings, format: format, quality: quality)
                case .merged:
                    result = try await mergeAndExport(recordings, format: format, quality: quality)
                case .zip:
                    result = try await exportAsZip(recordings, format: format, quality: quality)
                }
                
                await MainActor.run {
                    self.isExporting = false
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.exportError = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func exportIndividualFiles(
        _ recordings: [AudioFileInfo],
        format: AudioFileFormat,
        quality: ExportQuality
    ) async throws -> URL {
        let exportFolder = createExportFolder()
        
        for (index, recording) in recordings.enumerated() {
            let exportedURL = try await performExport(
                recording: recording,
                format: format,
                quality: quality
            )
            
            // Move to export folder
            let destinationURL = exportFolder.appendingPathComponent(exportedURL.lastPathComponent)
            try FileManager.default.moveItem(at: exportedURL, to: destinationURL)
            
            await MainActor.run {
                self.exportProgress = Double(index + 1) / Double(recordings.count)
            }
        }
        
        return exportFolder
    }
    
    private func mergeAndExport(
        _ recordings: [AudioFileInfo],
        format: AudioFileFormat,
        quality: ExportQuality
    ) async throws -> URL {
        let composition = AVMutableComposition()
        
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.compositionCreationFailed
        }
        
        var currentTime = CMTime.zero
        
        for (index, recording) in recordings.enumerated() {
            let asset = AVAsset(url: recording.url)
            
            guard let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                continue
            }
            
            let timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
            
            try audioTrack.insertTimeRange(timeRange, of: sourceTrack, at: currentTime)
            currentTime = CMTimeAdd(currentTime, timeRange.duration)
            
            await MainActor.run {
                self.exportProgress = Double(index + 1) / Double(recordings.count) * 0.5
            }
        }
        
        // Export merged composition
        let outputURL = createMergedExportURL(format: format)
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: quality.presetName
        ) else {
            throw ExportError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = format.avFileType
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw exportSession.error ?? ExportError.exportFailed
        case .cancelled:
            throw ExportError.exportCancelled
        default:
            throw ExportError.unexpectedStatus
        }
    }
    
    private func exportAsZip(
        _ recordings: [AudioFileInfo],
        format: AudioFileFormat,
        quality: ExportQuality
    ) async throws -> URL {
        // First export individual files
        let exportFolder = try await exportIndividualFiles(recordings, format: format, quality: quality)
        
        // Create zip file
        let zipURL = createZipURL()
        try await createZipFile(from: exportFolder, to: zipURL)
        
        // Clean up temporary folder
        try FileManager.default.removeItem(at: exportFolder)
        
        return zipURL
    }
    
    private func createZipFile(from sourceURL: URL, to destinationURL: URL) async throws {
        // Implementation would use a zip library like ZIPFoundation
        // For now, this is a placeholder
        throw ExportError.zipCreationNotImplemented
    }
    
    private func createExportURL(for recording: AudioFileInfo, format: AudioFileFormat) -> URL {
        let fileName = "\(recording.title).\(format.rawValue)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }
    
    private func createExportFolder() -> URL {
        let folderName = "Voice_Recordings_\(DateFormatter.exportFormatter.string(from: Date()))"
        let folderURL = FileManager.default.temporaryDirectory.appendingPathComponent(folderName)
        
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        return folderURL
    }
    
    private func createMergedExportURL(format: AudioFileFormat) -> URL {
        let fileName = "Merged_Recording_\(DateFormatter.exportFormatter.string(from: Date())).\(format.rawValue)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }
    
    private func createZipURL() -> URL {
        let fileName = "Voice_Recordings_\(DateFormatter.exportFormatter.string(from: Date())).zip"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }
}

// MARK: - Supporting Types

enum ExportQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case highest = "highest"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low Quality"
        case .medium:
            return "Medium Quality"
        case .high:
            return "High Quality"
        case .highest:
            return "Highest Quality"
        }
    }
    
    var presetName: String {
        switch self {
        case .low:
            return AVAssetExportPresetLowQuality
        case .medium:
            return AVAssetExportPresetMediumQuality
        case .high:
            return AVAssetExportPresetHighestQuality
        case .highest:
            return AVAssetExportPresetPassthrough
        }
    }
}

enum MultipleExportType: String, CaseIterable {
    case individual = "individual"
    case merged = "merged"
    case zip = "zip"
    
    var displayName: String {
        switch self {
        case .individual:
            return "Individual Files"
        case .merged:
            return "Merged Audio"
        case .zip:
            return "ZIP Archive"
        }
    }
}

enum ExportError: LocalizedError {
    case exportSessionCreationFailed
    case exportFailed
    case exportCancelled
    case unexpectedStatus
    case compositionCreationFailed
    case zipCreationNotImplemented
    
    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed:
            return "Export failed"
        case .exportCancelled:
            return "Export was cancelled"
        case .unexpectedStatus:
            return "Unexpected export status"
        case .compositionCreationFailed:
            return "Failed to create audio composition"
        case .zipCreationNotImplemented:
            return "ZIP creation not implemented"
        }
    }
}

extension DateFormatter {
    static let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}

extension AudioFileFormat {
    var avFileType: AVFileType {
        switch self {
        case .m4a:
            return .m4a
        case .wav:
            return .wav
        case .mp3:
            return .mp3
        case .aiff:
            return .aiff
        }
    }
}
