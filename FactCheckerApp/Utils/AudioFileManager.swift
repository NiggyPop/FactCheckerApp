//
//  AudioFileManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import SwiftUI

extension AudioFileManager {
    func getDetailedStorageInfo() async -> StorageInfo {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let files = self.getAllAudioFiles()
                
                var totalSize: Int64 = 0
                var fileTypeStats: [AudioFileFormat: (count: Int, size: Int64)] = [:]
                var oldestDate: Date?
                var newestDate: Date?
                
                for file in files {
                    totalSize += file.size
                    
                    // Update file type stats
                    if var stats = fileTypeStats[file.format] {
                        stats.count += 1
                        stats.size += file.size
                        fileTypeStats[file.format] = stats
                    } else {
                        fileTypeStats[file.format] = (count: 1, size: file.size)
                    }
                    
                    // Track oldest and newest files
                    if oldestDate == nil || file.creationDate < oldestDate! {
                        oldestDate = file.creationDate
                    }
                    if newestDate == nil || file.creationDate > newestDate! {
                        newestDate = file.creationDate
                    }
                }
                
                let categoryBreakdown = self.createCategoryBreakdown(files: files, totalSize: totalSize)
                let fileTypeBreakdown = fileTypeStats.map { format, stats in
                    FileTypeBreakdown(format: format, count: stats.count, size: stats.size)
                }.sorted { $0.size > $1.size }
                
                let averageFileSize = files.isEmpty ? 0 : totalSize / Int64(files.count)
                
                let storageInfo = StorageInfo(
                    totalSize: totalSize,
                    totalFiles: files.count,
                    categoryBreakdown: categoryBreakdown,
                    fileTypeBreakdown: fileTypeBreakdown,
                    oldestFile: oldestDate,
                    newestFile: newestDate,
                    averageFileSize: averageFileSize
                )
                
                continuation.resume(returning: storageInfo)
            }
        }
    }
    
    private func createCategoryBreakdown(files: [AudioFileInfo], totalSize: Int64) -> [CategoryBreakdown] {
        let now = Date()
        let calendar = Calendar.current
        
        var recentSize: Int64 = 0  // Last 7 days
        var oldSize: Int64 = 0     // Older than 30 days
        var mediumSize: Int64 = 0  // 7-30 days
        
        for file in files {
            let daysSinceCreation = calendar.dateComponents([.day], from: file.creationDate, to: now).day ?? 0
            
            if daysSinceCreation <= 7 {
                recentSize += file.size
            } else if daysSinceCreation <= 30 {
                mediumSize += file.size
            } else {
                oldSize += file.size
            }
        }
        
        let breakdown: [CategoryBreakdown] = [
            CategoryBreakdown(
                category: "Recent (7 days)",
                size: recentSize,
                percentage: totalSize > 0 ? Double(recentSize) / Double(totalSize) * 100 : 0,
                color: .green
            ),
            CategoryBreakdown(
                category: "Medium (7-30 days)",
                size: mediumSize,
                percentage: totalSize > 0 ? Double(mediumSize) / Double(totalSize) * 100 : 0,
                color: .orange
            ),
            CategoryBreakdown(
                category: "Old (30+ days)",
                size: oldSize,
                percentage: totalSize > 0 ? Double(oldSize) / Double(totalSize) * 100 : 0,
                color: .red
            )
        ]
        
        return breakdown.filter { $0.size > 0 }
    }
    
    func performCleanup(options: Set<CleanupOption>) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                for option in options {
                    switch option {
                    case .temporaryFiles:
                        self.cleanupTemporaryFiles()
                    case .oldRecordings:
                        self.cleanupOldRecordings()
                    case .duplicateFiles:
                        self.cleanupDuplicateFiles()
                    case .largeFiles:
                        self.cleanupLargeFiles()
                    case .corruptedFiles:
                        self.cleanupCorruptedFiles()
                    }
                }
                continuation.resume()
            }
        }
    }
    
    private func cleanupOldRecordings() {
        let files = getAllAudioFiles()
        let calendar = Calendar.current
        let now = Date()
        
        for file in files {
            let daysSinceCreation = calendar.dateComponents([.day], from: file.creationDate, to: now).day ?? 0
            if daysSinceCreation > 30 {
                try? FileManager.default.removeItem(at: file.url)
            }
        }
    }
    
    private func cleanupDuplicateFiles() {
        let files = getAllAudioFiles()
        var seenHashes: Set<String> = []
        
        for file in files {
            if let hash = calculateFileHash(url: file.url) {
                if seenHashes.contains(hash) {
                    try? FileManager.default.removeItem(at: file.url)
                } else {
                    seenHashes.insert(hash)
                }
            }
        }
    }
    
    private func cleanupLargeFiles() {
        let files = getAllAudioFiles()
        let threshold: Int64 = 100 * 1024 * 1024 // 100MB
        
        for file in files {
            if file.size > threshold {
                // Could show confirmation dialog for each large file
                // For now, we'll skip automatic deletion of large files
            }
        }
    }
    
    private func cleanupCorruptedFiles() {
        let files = getAllAudioFiles()
        
        for file in files {
            if !isValidAudioFile(url: file.url) {
                try? FileManager.default.removeItem(at: file.url)
            }
        }
    }
    
    private func calculateFileHash(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return data.sha256
    }
    
    private func isValidAudioFile(url: URL) -> Bool {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            return audioFile.length > 0
        } catch {
            return false
        }
    }
}

extension Data {
    var sha256: String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

import CryptoKit
