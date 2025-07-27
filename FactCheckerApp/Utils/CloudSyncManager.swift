//
//  CloudSyncManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import CloudKit

class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let container = CKContainer.default()
    private let database: CKDatabase
    
    private init() {
        database = container.privateCloudDatabase
        checkAccountStatus()
    }
    
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    print("iCloud account available")
                case .noAccount:
                    print("No iCloud account")
                case .restricted:
                    print("iCloud account restricted")
                case .couldNotDetermine:
                    print("Could not determine iCloud account status")
                    if let error = error {
                        self?.syncError = error
                    }
                @unknown default:
                    print("Unknown iCloud account status")
                }
            }
        }
    }
    
    func syncRecordings() async {
        guard !isSyncing else { return }
        
        await MainActor.run {
            isSyncing = true
            syncProgress = 0
            syncError = nil
        }
        
        do {
            let recordings = AudioFileManager.shared.getAllAudioFiles()
            let totalRecordings = recordings.count
            
            for (index, recording) in recordings.enumerated() {
                try await syncRecording(recording)
                
                await MainActor.run {
                    syncProgress = Double(index + 1) / Double(totalRecordings)
                }
            }
            
            await MainActor.run {
                lastSyncDate = Date()
                isSyncing = false
            }
            
        } catch {
            await MainActor.run {
                syncError = error
                isSyncing = false
            }
        }
    }
    
    private func syncRecording(_ recording: AudioFileInfo) async throws {
        // Check if recording already exists in CloudKit
        let recordID = CKRecord.ID(recordName: recording.id.uuidString)
        
        do {
            let existingRecord = try await database.record(for: recordID)
            // Update existing record if needed
            try await updateRecordIfNeeded(existingRecord, with: recording)
        } catch {
            // Record doesn't exist, create new one
            try await createNewRecord(for: recording)
        }
    }
    
    private func createNewRecord(for recording: AudioFileInfo) async throws {
        let record = CKRecord(recordType: "AudioRecording", recordID: CKRecord.ID(recordName: recording.id.uuidString))
        
        record["title"] = recording.title
        record["creationDate"] = recording.creationDate
        record["duration"] = recording.duration
        record["size"] = recording.size
        record["format"] = recording.format.rawValue
        
        // Upload audio file
        let asset = CKAsset(fileURL: recording.url)
        record["audioFile"] = asset
        
        _ = try await database.save(record)
    }
    
    private func updateRecordIfNeeded(_ record: CKRecord, with recording: AudioFileInfo) async throws {
        var needsUpdate = false
        
        if record["title"] as? String != recording.title {
            record["title"] = recording.title
            needsUpdate = true
        }
        
        if needsUpdate {
            _ = try await database.save(record)
        }
    }
    
    func downloadRecordings() async {
        guard !isSyncing else { return }
        
        await MainActor.run {
            isSyncing = true
            syncProgress = 0
            syncError = nil
        }
        
        do {
            let query = CKQuery(recordType: "AudioRecording", predicate: NSPredicate(value: true))
            let records = try await database.records(matching: query).matchResults.compactMap { try? $0.1.get() }
            
            for (index, record) in records.enumerated() {
                try await downloadRecording(record)
                
                await MainActor.run {
                    syncProgress = Double(index + 1) / Double(records.count)
                }
            }
            
            await MainActor.run {
                lastSyncDate = Date()
                isSyncing = false
            }
            
        } catch {
            await MainActor.run {
                syncError = error
                isSyncing = false
            }
        }
    }
    
    private func downloadRecording(_ record: CKRecord) async throws {
        guard let asset = record["audioFile"] as? CKAsset,
              let fileURL = asset.fileURL else {
            return
        }
        
        let title = record["title"] as? String ?? "Untitled"
        let creationDate = record["creationDate"] as? Date ?? Date()
        let format = AudioFileFormat(rawValue: record["format"] as? String ?? "m4a") ?? .m4a
        
        // Copy file to local storage
        let localURL = AudioFileManager.shared.documentsDirectory
            .appendingPathComponent("\(UUID().uuidString).\(format.rawValue)")
        
        try FileManager.default.copyItem(at: fileURL, to: localURL)
        
        // Update local database/storage
        // This would integrate with your local file management system
    }
    
    func deleteRecordingFromCloud(_ recordingID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: recordingID.uuidString)
        _ = try await database.deleteRecord(withID: recordID)
    }
}
