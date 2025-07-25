//
//  AppConstants.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation

struct AppConstants {
    // API Configuration
    struct API {
        static let baseURL = "https://api.factcheck.com/v1"
        static let timeout: TimeInterval = 30.0
        static let maxRetries = 3
    }
    
    // Audio Configuration
    struct Audio {
        static let sampleRate: Double = 16000
        static let bufferSize: Int = 1024
        static let maxRecordingDuration: TimeInterval = 300 // 5 minutes
        static let silenceThreshold: Float = -50.0 // dB
    }
    
    // UI Configuration
    struct UI {
        static let animationDuration: Double = 0.3
        static let hapticFeedbackEnabled = true
        static let maxHistoryItems = 1000
        static let defaultConfidenceThreshold: Double = 0.7
    }
    
    // Fact Checking
    struct FactCheck {
        static let minStatementLength = 10
        static let maxStatementLength = 1000
        static let defaultSourceCount = 5
        static let cacheExpirationTime: TimeInterval = 3600 // 1 hour
    }
    
    // Speaker Recognition
    struct Speaker {
        static let minVoiceSampleDuration: TimeInterval = 3.0
        static let maxVoiceSampleDuration: TimeInterval = 30.0
        static let recognitionThreshold: Double = 0.8
    }
    
    // Data Storage
    struct Storage {
        static let maxCacheSize: Int = 100 * 1024 * 1024 // 100MB
        static let backupInterval: TimeInterval = 86400 // 24 hours
        static let maxHistoryAge: TimeInterval = 2592000 // 30 days
    }
}

struct NotificationNames {
    static let factCheckCompleted = Notification.Name("factCheckCompleted")
    static let speakerIdentified = Notification.Name("speakerIdentified")
    static let audioLevelChanged = Notification.Name("audioLevelChanged")
    static let settingsChanged = Notification.Name("settingsChanged")
}

struct UserDefaultsKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let userPreferences = "userPreferences"
    static let cachedResults = "cachedResults"
    static let speakerProfiles = "speakerProfiles"
}
