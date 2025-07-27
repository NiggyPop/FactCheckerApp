//
//  AudioFileManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import AVFoundation
import Compression

class AudioFileManager {
    static let shared = AudioFileManager()
    
    private let documentsDirectory: URL
    private let audioDirectory: URL
    private let tempDirectory: URL
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        audioDirectory = documentsDirectory.appendingPathComponent("Audio", isDirectory: true)
        tempDirectory = documentsDirectory.appendingPathComponent("Temp", isDirectory: true)
        
        createDirectoriesIfNeeded()
    }
    
    // MARK: - Directory Management
    
    private func createDirectoriesIfNeeded() {
        let directories = [audioDirectory, tempDirectory]
        
        for directory in directories {
            if !FileManager.default.fileExists(atPath: directory.path) {
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    print("Failed to create directory \(directory): \(error)")
                }
            }
        }
    }
    
    // MARK: - Audio File Operations
    
    func saveAudioFile(_ buffer: AVAudioPCMBuffer, filename: String, format: AudioFileFormat = .m4a) async throws -> URL {
        let fileURL = audioDirectory.appendingPathComponent("\(filename).\(format.fileExtension)")
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let audioFile = try AVAudioFile(
                    forWriting: fileURL,
                    settings: format.audioSettings(for: buffer.format)
                )
                
                try audioFile.write(from: buffer)
                continuation.resume(returning: fileURL)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func loadAudioFile(from url: URL) async throws -> AVAudioPCMBuffer {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let audioFile = try AVAudioFile(forReading: url)
                
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: audioFile.processingFormat,
                    frameCapacity: AVAudioFrameCount(audioFile.length)
                ) else {
                    throw AudioFileError.bufferCreationFailed
                }
                
                try audioFile.read(into: buffer)
                continuation.resume(returning: buffer)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func compressAudioFile(at sourceURL: URL, to destinationURL: URL, quality: AudioCompressionQuality = .medium) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let asset = AVAsset(url: sourceURL)
            
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: quality.exportPreset) else {
                continuation.resume(throwing: AudioFileError.exportSessionCreationFailed)
                return
            }
            
            exportSession.outputURL = destinationURL
            exportSession.outputFileType = .m4a
            
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? AudioFileError.compressionFailed)
                case .cancelled:
                    continuation.resume(throwing: AudioFileError.operationCancelled)
                default:
                    continuation.resume(throwing: AudioFileError.unknownError)
                }
            }
        }
    }
    
    func mergeAudioFiles(_ urls: [URL], outputURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let composition = AVMutableComposition()
            
            guard let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                continuation.resume(throwing: AudioFileError.compositionCreationFailed)
                return
            }
            
            var currentTime = CMTime.zero
            
            do {
                for url in urls {
                    let asset = AVAsset(url: url)
                    let duration = try await asset.load(.duration)
                    
                    if let assetTrack = try await asset.loadTracks(withMediaType: .audio).first {
                        try audioTrack.insertTimeRange(
                            CMTimeRange(start: .zero, duration: duration),
                            of: assetTrack,
                            at: currentTime
                        )
                        currentTime = CMTimeAdd(currentTime, duration)
                    }
                }
                
                guard let exportSession = AVAssetExportSession(
                    asset: composition,
                    presetName: AVAssetExportPresetAppleM4A
                ) else {
                    continuation.resume(throwing: AudioFileError.exportSessionCreationFailed)
                    return
                }
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .m4a
                
                exportSession.exportAsynchronously {
                    switch exportSession.status {
                    case .completed:
                        continuation.resume()
                    case .failed:
                        continuation.resume(throwing: exportSession.error ?? AudioFileError.mergeFailed)
                    case .cancelled:
                        continuation.resume(throwing: AudioFileError.operationCancelled)
                    default:
                        continuation.resume(throwing: AudioFileError.unknownError)
                    }
                }
                
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func trimAudioFile(at url: URL, startTime: TimeInterval, duration: TimeInterval, outputURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let asset = AVAsset(url: url)
            
            guard let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetAppleM4A
            ) else {
                continuation.resume(throwing: AudioFileError.exportSessionCreationFailed)
                return
            }
            
            let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
            let durationCMTime = CMTime(seconds: duration, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startCMTime, duration: durationCMTime)
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a
            exportSession.timeRange = timeRange
            
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? AudioFileError.trimFailed)
                case .cancelled:
                    continuation.resume(throwing: AudioFileError.operationCancelled)
                default:
                    continuation.resume(throwing: AudioFileError.unknownError)
                }
            }
        }
    }
    
    // MARK: - File Management
    
    func getAllAudioFiles() -> [AudioFileInfo] {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey]
        ) else {
            return []
        }
        
        return fileURLs.compactMap { url in
            guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey]) else {
                return nil
            }
            
            return AudioFileInfo(
                url: url,
                name: url.deletingPathExtension().lastPathComponent,
                size: resourceValues.fileSize ?? 0,
                creationDate: resourceValues.creationDate ?? Date(),
                modificationDate: resourceValues.contentModificationDate ?? Date(),
                format: AudioFileFormat.from(fileExtension: url.pathExtension)
            )
        }.sorted { $0.modificationDate > $1.modificationDate }
    }
    
    func deleteAudioFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    func getAudioFileDuration(at url: URL) async throws -> TimeInterval {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
    
    func getAudioFileMetadata(at url: URL) async throws -> [String: Any] {
        let asset = AVAsset(url: url)
        let metadata = try await asset.load(.metadata)
        
        var metadataDict: [String: Any] = [:]
        
        for item in metadata {
            if let key = item.commonKey?.rawValue,
               let value = try await item.load(.value) {
                metadataDict[key] = value
            }
        }
        
        return metadataDict
    }
    
    // MARK: - Temporary Files
    
    func createTemporaryAudioFile(format: AudioFileFormat = .m4a) -> URL {
        let filename = UUID().uuidString
        return tempDirectory.appendingPathComponent("\(filename).\(format.fileExtension)")
    }
    
    func cleanupTemporaryFiles() {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for url in fileURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Storage Management
    
    func getStorageUsage() -> StorageInfo {
        let audioFiles = getAllAudioFiles()
        let totalSize = audioFiles.reduce(0) { $0 + $1.size }
        let fileCount = audioFiles.count
        
        return StorageInfo(
            totalSize: totalSize,
            fileCount: fileCount,
            availableSpace: getAvailableSpace()
        )
    }
    
    private func getAvailableSpace() -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: documentsDirectory.path),
              let freeSize = attributes[.systemFreeSize] as? Int64 else {
            return 0
        }
        return freeSize
    }
}

// MARK: - Supporting Types

enum AudioFileFormat: String, CaseIterable {
    case wav = "wav"
    case m4a = "m4a"
    case mp3 = "mp3"
    case aac = "aac"
    
    var fileExtension: String {
        return rawValue
    }
    
    var mimeType: String {
        switch self {
        case .wav:
            return "audio/wav"
        case .m4a:
            return "audio/mp4"
        case .mp3:
            return "audio/mpeg"
        case .aac:
            return "audio/aac"
        }
    }
    
    func audioSettings(for format: AVAudioFormat) -> [String: Any] {
        switch self {
        case .wav:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        case .m4a, .aac:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        case .mp3:
            return [
                AVFormatIDKey: kAudioFormatMPEGLayer3,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderBitRateKey: 128000
            ]
        }
    }
    
    static func from(fileExtension: String) -> AudioFileFormat {
        return AudioFileFormat(rawValue: fileExtension.lowercased()) ?? .m4a
    }
}

enum AudioCompressionQuality {
    case low
    case medium
    case high
    
    var exportPreset: String {
        switch self {
        case .low:
            return AVAssetExportPresetLowQuality
        case .medium:
            return AVAssetExportPresetMediumQuality
        case .high:
            return AVAssetExportPresetHighestQuality
        }
    }
}

struct AudioFileInfo {
    let url: URL
    let name: String
    let size: Int
    let creationDate: Date
    let modificationDate: Date
    let format: AudioFileFormat
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    var formattedDuration: String {
        // This would need to be populated separately via getAudioFileDuration
        return "Unknown"
    }
}

struct StorageInfo {
    let totalSize: Int
    let fileCount: Int
    let availableSpace: Int64
    
    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }
    
    var formattedAvailableSpace: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: availableSpace)
    }
}

enum AudioFileError: Error, LocalizedError {
    case bufferCreationFailed
    case exportSessionCreationFailed
    case compressionFailed
    case operationCancelled
    case unknownError
    case compositionCreationFailed
    case mergeFailed
    case trimFailed
    
    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .compressionFailed:
            return "Audio compression failed"
        case .operationCancelled:
            return "Operation was cancelled"
        case .unknownError:
            return "An unknown error occurred"
        case .compositionCreationFailed:
            return "Failed to create audio composition"
        case .mergeFailed:
            return "Failed to merge audio files"
        case .trimFailed:
            return "Failed to trim audio file"
        }
    }
}
