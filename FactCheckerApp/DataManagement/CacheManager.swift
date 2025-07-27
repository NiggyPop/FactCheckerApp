//
//  CacheManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import Combine

class CacheManager: ObservableObject {
    private let cache = NSCache<NSString, CacheItem>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int = AppConfig.Storage.maxCacheSize
    private let cacheExpirationTime: TimeInterval = AppConfig.FactCheck.cacheExpirationTime
    
    @Published var cacheSize: Int = 0
    
    init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("Cache")
        
        setupCache()
        calculateCacheSize()
    }
    
    // MARK: - Public Methods
    
    func store<T: Codable>(_ object: T, forKey key: String, expiration: TimeInterval? = nil) {
        let expirationDate = Date().addingTimeInterval(expiration ?? cacheExpirationTime)
        let cacheItem = CacheItem(object: object, expirationDate: expirationDate)
        
        cache.setObject(cacheItem, forKey: NSString(string: key))
        
        // Also store to disk for persistence
        storeToDisk(cacheItem, forKey: key)
        
        updateCacheSize()
    }
    
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        // First check memory cache
        if let cacheItem = cache.object(forKey: NSString(string: key)) {
            if cacheItem.isValid {
                return cacheItem.object as? T
            } else {
                // Remove expired item
                cache.removeObject(forKey: NSString(string: key))
                removeFromDisk(forKey: key)
            }
        }
        
        // Check disk cache
        if let cacheItem = retrieveFromDisk(forKey: key) {
            if cacheItem.isValid {
                // Store back in memory cache
                cache.setObject(cacheItem, forKey: NSString(string: key))
                return cacheItem.object as? T
            } else {
                // Remove expired item
                removeFromDisk(forKey: key)
            }
        }
        
        return nil
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: NSString(string: key))
        removeFromDisk(forKey: key)
        updateCacheSize()
    }
    
    func clearCache() {
        cache.removeAllObjects()
        clearDiskCache()
        updateCacheSize()
    }
    
    func cleanExpiredItems() {
        // Clean memory cache
        let allKeys = getAllCacheKeys()
        for key in allKeys {
            if let cacheItem = cache.object(forKey: NSString(string: key)),
               !cacheItem.isValid {
                cache.removeObject(forKey: NSString(string: key))
                removeFromDisk(forKey: key)
            }
        }
        
        // Clean disk cache
        cleanExpiredDiskItems()
        updateCacheSize()
    }
    
    func getCacheStatistics() -> CacheStatistics {
        let memoryCount = cache.totalCostLimit
        let diskSize = calculateDiskCacheSize()
        let totalItems = getAllCacheKeys().count
        
        return CacheStatistics(
            memoryItems: memoryCount,
            diskSize: diskSize,
            totalItems: totalItems,
            lastCleanup: UserDefaults.standard.object(forKey: "lastCacheCleanup") as? Date ?? Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupCache() {
        cache.totalCostLimit = maxCacheSize
        cache.countLimit = 1000
        
        // Create cache directory if needed
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Schedule periodic cleanup
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            self.cleanExpiredItems()
        }
    }
    
    private func storeToDisk<T: Codable>(_ cacheItem: CacheItem, forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        do {
            let data = try JSONEncoder().encode(cacheItem)
            try data.write(to: fileURL)
        } catch {
            print("Failed to store cache item to disk: \(error)")
        }
    }
    
    private func retrieveFromDisk(forKey key: String) -> CacheItem? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(CacheItem.self, from: data)
        } catch {
            print("Failed to retrieve cache item from disk: \(error)")
            return nil
        }
    }
    
    private func removeFromDisk(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: fileURL)
    }
    
    private func clearDiskCache() {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }
    
    private func cleanExpiredDiskItems() {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        
        for file in files {
            if let cacheItem = try? JSONDecoder().decode(CacheItem.self, from: Data(contentsOf: file)),
               !cacheItem.isValid {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    private func getAllCacheKeys() -> [String] {
        // This is a simplified implementation
        // In a real app, you might want to maintain a separate list of keys
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return [] }
        
        return files.compactMap { url in
            let filename = url.lastPathComponent
            return filename.hasSuffix(".cache") ? String(filename.dropLast(6)) : nil
        }
    }
    
    private func calculateCacheSize() {
        DispatchQueue.global(qos: .utility).async {
            let size = self.calculateDiskCacheSize()
            DispatchQueue.main.async {
                self.cacheSize = size
            }
        }
    }
    
    private func calculateDiskCacheSize() -> Int {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        
        return files.reduce(0) { total, url in
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + fileSize
        }
    }
    
    private func updateCacheSize() {
        calculateCacheSize()
    }
}

// MARK: - Supporting Types

class CacheItem: NSObject, Codable {
    let object: Any
    let expirationDate: Date
    let creationDate: Date
    
    init<T: Codable>(object: T, expirationDate: Date) {
        self.object = object
        self.expirationDate = expirationDate
        self.creationDate = Date()
        super.init()
    }
    
    var isValid: Bool {
        return Date() < expirationDate
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case objectData
        case expirationDate
        case creationDate
        case objectType
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let objectData = try container.decode(Data.self, forKey: .objectData)
        let objectType = try container.decode(String.self, forKey: .objectType)
        
        // This is a simplified approach - in production you'd want more robust type handling
        if objectType == "FactCheckResult" {
            self.object = try JSONDecoder().decode(FactCheckResult.self, from: objectData)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Unknown object type"))
        }
        
        self.expirationDate = try container.decode(Date.self, forKey: .expirationDate)
        self.creationDate = try container.decode(Date.self, forKey: .creationDate)
        
        super.init()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let objectData = try JSONEncoder().encode(object as! FactCheckResult)
        try container.encode(objectData, forKey: .objectData)
        try container.encode("FactCheckResult", forKey: .objectType)
        try container.encode(expirationDate, forKey: .expirationDate)
        try container.encode(creationDate, forKey: .creationDate)
    }
}

struct CacheStatistics {
    let memoryItems: Int
    let diskSize: Int
    let totalItems: Int
    let lastCleanup: Date
}
