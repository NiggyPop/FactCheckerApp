//
//  StorageInfo.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import SwiftUI

struct StorageInfo {
    let totalSize: Int64
    let totalFiles: Int
    let categoryBreakdown: [CategoryBreakdown]
    let fileTypeBreakdown: [FileTypeBreakdown]
    let oldestFile: Date?
    let newestFile: Date?
    let averageFileSize: Int64
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    func potentialSavings(for option: CleanupOption) -> String {
        // Calculate potential savings for each cleanup option
        switch option {
        case .temporaryFiles:
            return "~5 MB" // Placeholder
        case .oldRecordings:
            return "~\(ByteCountFormatter.string(fromByteCount: totalSize / 4, countStyle: .file))"
        case .duplicateFiles:
            return "~2 MB" // Placeholder
        case .largeFiles:
            return "~10 MB" // Placeholder
        case .corruptedFiles:
            return "~1 MB" // Placeholder
        }
    }
}

struct CategoryBreakdown {
    let category: String
    let size: Int64
    let percentage: Double
    let color: Color
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct FileTypeBreakdown {
    let format: AudioFileFormat
    let count: Int
    let size: Int64
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
