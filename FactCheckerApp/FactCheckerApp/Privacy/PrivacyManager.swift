//
//  PrivacyManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import Combine

class PrivacyManager: ObservableObject {
    @Published var dataRetentionPeriod: DataRetentionPeriod = .oneMonth
    @Published var allowAnalytics = false
    @Published var allowCrashReporting = true
    @Published var shareAnonymousUsage = false
    @Published var localProcessingOnly = false
    
    private let dataManager: DataManager
    private var cleanupTimer: Timer?
    
    enum DataRetentionPeriod: String, CaseIterable {
        case oneWeek = "1_week"
        case oneMonth = "1_month"
        case threeMonths = "3_months"
        case sixMonths = "6_months"
        case oneYear = "1_year"
        case forever = "forever"
        
        var displayName: String {
            switch self {
            case .oneWeek: return L("retention_1week")
            case .oneMonth: return L("retention_1month")
            case .threeMonths: return L("retention_3months")
            case .sixMonths: return L("retention_6months")
            case .oneYear: return L("retention_1year")
            case .forever: return L("retention_forever")
            }
        }
        
        var timeInterval: TimeInterval? {
            switch self {
            case .oneWeek: return 7 * 24 * 60 * 60
            case .oneMonth: return 30 * 24 * 60 * 60
            case .threeMonths: return 90 * 24 * 60 * 60
            case .sixMonths: return 180 * 24 * 60 * 60
            case .oneYear: return 365 * 24 * 60 * 60
            case .forever: return nil
            }
        }
    }
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
        loadSettings()
        setupAutomaticCleanup()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    func updateDataRetentionPeriod(_ period: DataRetentionPeriod) {
        dataRetentionPeriod = period
        saveSettings()
        
        // Immediately clean up old data if retention period was shortened
        cleanupOldData()
    }
    
    func updateAnalyticsPermission(_ allowed: Bool) {
        allowAnalytics = allowed
        saveSettings()
        
        if !allowed {
            // Clear existing analytics data
            clearAnalyticsData()
        }
    }
    
    func updateCrashReportingPermission(_ allowed: Bool) {
        allowCrashReporting = allowed
        saveSettings()
    }
    
    func updateAnonymousUsageSharing(_ allowed: Bool) {
        shareAnonymousUsage = allowed
        saveSettings()
    }
    
    func updateLocalProcessingPreference(_ localOnly: Bool) {
        localProcessingOnly = localOnly
        saveSettings()
    }
    
    func exportPersonalData() -> PersonalDataExport {
        let factCheckResults = dataManager.getAllFactCheckResults()
        let speakers = dataManager.getAllSpeakers()
        
        return PersonalDataExport(
            exportDate: Date(),
            factCheckResults: factCheckResults,
            speakers: speakers,
            settings: getCurrentSettings()
        )
    }
    
    func deleteAllPersonalData() async throws {
        try await dataManager.deleteAllData()
        clearAnalyticsData()
        clearCacheData()
        resetSettings()
    }
    
    func getDataUsageReport() -> DataUsageReport {
        let factCheckCount = dataManager.getFactCheckResultCount()
        let speakerCount = dataManager.getSpeakerCount()
        let storageSize = calculateStorageSize()
        let oldestRecord = dataManager.getOldestFactCheckResult()?.timestamp
        
        return DataUsageReport(
            totalFactChecks: factCheckCount,
            totalSpeakers: speakerCount,
            storageSize: storageSize,
            oldestRecord: oldestRecord,
            retentionPeriod: dataRetentionPeriod,
            lastCleanup: UserDefaults.standard.object(forKey: "last_data_cleanup") as? Date
        )
    }
    
    // MARK: - Data Cleanup
    
    func cleanupOldData() {
        guard let retentionInterval = dataRetentionPeriod.timeInterval else { return }
        
        let cutoffDate = Date().addingTimeInterval(-retentionInterval)
        
        Task {
            do {
                try await dataManager.deleteFactCheckResults(olderThan: cutoffDate)
                try await dataManager.deleteUnusedSpeakers()
                
                DispatchQueue.main.async {
                    UserDefaults.standard.set(Date(), forKey: "last_data_cleanup")
                }
            } catch {
                print("Error cleaning up old data: \(error)")
            }
        }
    }
    
    private func clearAnalyticsData() {
        // Clear analytics data
        UserDefaults.standard.removeObject(forKey: "analytics_data")
        
        // Notify analytics manager
        NotificationCenter.default.post(name: .clearAnalyticsData, object: nil)
    }
    
    private func clearCacheData() {
        // Clear cache
        NotificationCenter.default.post(name: .clearCacheData, object: nil)
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        if let retentionString = UserDefaults.standard.string(forKey: "data_retention_period"),
           let retention = DataRetentionPeriod(rawValue: retentionString) {
            dataRetentionPeriod = retention
        }
        
        allowAnalytics = UserDefaults.standard.bool(forKey: "allow_analytics")
        allowCrashReporting = UserDefaults.standard.bool(forKey: "allow_crash_reporting")
        shareAnonymousUsage = UserDefaults.standard.bool(forKey: "share_anonymous_usage")
        localProcessingOnly = UserDefaults.standard.bool(forKey: "local_processing_only")
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(dataRetentionPeriod.rawValue, forKey: "data_retention_period")
        UserDefaults.standard.set(allowAnalytics, forKey: "allow_analytics")
        UserDefaults.standard.set(allowCrashReporting, forKey: "allow_crash_reporting")
        UserDefaults.standard.set(shareAnonymousUsage, forKey: "share_anonymous_usage")
        UserDefaults.standard.set(localProcessingOnly, forKey: "local_processing_only")
    }
    
    private func resetSettings() {
        dataRetentionPeriod = .oneMonth
        allowAnalytics = false
        allowCrashReporting = true
        shareAnonymousUsage = false
        localProcessingOnly = false
        saveSettings()
    }
    
    private func getCurrentSettings() -> PrivacySettings {
        return PrivacySettings(
            dataRetentionPeriod: dataRetentionPeriod,
            allowAnalytics: allowAnalytics,
            allowCrashReporting: allowCrashReporting,
            shareAnonymousUsage: shareAnonymousUsage,
            localProcessingOnly: localProcessingOnly
        )
    }
    
    // MARK: - Automatic Cleanup
    
    private func setupAutomaticCleanup() {
        // Run cleanup daily
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            self.cleanupOldData()
        }
    }
    
    private func calculateStorageSize() -> Int64 {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        guard let enumerator = FileManager.default.enumerator(
            at: documentsPath,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                continue
            }
        }
        
        return totalSize
    }
}

// MARK: - Supporting Types

struct PersonalDataExport: Codable {
    let exportDate: Date
    let factCheckResults: [FactCheckResult]
    let speakers: [Speaker]
    let settings: PrivacySettings
}

struct PrivacySettings: Codable {
    let dataRetentionPeriod: PrivacyManager.DataRetentionPeriod
    let allowAnalytics: Bool
    let allowCrashReporting: Bool
    let shareAnonymousUsage: Bool
    let localProcessingOnly: Bool
}

struct DataUsageReport {
    let totalFactChecks: Int
    let totalSpeakers: Int
    let storageSize: Int64
    let oldestRecord: Date?
    let retentionPeriod: PrivacyManager.DataRetentionPeriod
    let lastCleanup: Date?
    
    var formattedStorageSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: storageSize)
    }
}

extension Notification.Name {
    static let clearAnalyticsData = Notification.Name("clearAnalyticsData")
    static let clearCacheData = Notification.Name("clearCacheData")
}
