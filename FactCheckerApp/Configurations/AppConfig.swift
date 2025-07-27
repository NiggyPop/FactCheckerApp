//
//  AppConfig.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation

struct AppConfig {
    // MARK: - Build Configuration
    static let isDebug: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    static let isTestFlight: Bool = {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("sandboxReceipt")
    }()
    
    static let isAppStore: Bool = {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("receipt") && !path.contains("sandboxReceipt")
    }()
    
    // MARK: - API Configuration
    struct API {
        static let baseURL: String = {
            if isDebug {
                return "https://api-dev.factcheck.com/v1"
            } else if isTestFlight {
                return "https://api-staging.factcheck.com/v1"
            } else {
                return "https://api.factcheck.com/v1"
            }
        }()
        
        static let timeout: TimeInterval = 30.0
        static let maxRetries = 3
        static let apiKey = getAPIKey()
        
        private static func getAPIKey() -> String {
            guard let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
                  let plist = NSDictionary(contentsOfFile: path),
                  let key = plist["FactCheckAPIKey"] as? String else {
                fatalError("API Key not found in APIKeys.plist")
            }
            return key
        }
    }
    
    // MARK: - Feature Flags
    struct FeatureFlags {
        static let enableAdvancedAnalytics = true
        static let enableSpeakerIdentification = true
        static let enableRealTimeFactChecking = true
        static let enableOfflineMode = false
        static let enableBetaFeatures = isDebug || isTestFlight
        static let enableCrashReporting = !isDebug
        static let enablePerformanceMonitoring = true
    }
    
    // MARK: - App Information
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.factcheck.pro"
    
    // MARK: - URLs
    struct URLs {
        static let privacyPolicy = "https://factcheckpro.com/privacy"
        static let termsOfService = "https://factcheckpro.com/terms"
        static let support = "https://factcheckpro.com/support"
        static let appStore = "https://apps.apple.com/app/id123456789"
        static let website = "https://factcheckpro.com"
    }
    
    // MARK: - Analytics
    struct Analytics {
        static let enabledInDebug = false
        static let enabledInTestFlight = true
        static let enabledInProduction = true
        
        static var isEnabled: Bool {
            if isDebug { return enabledInDebug }
            if isTestFlight { return enabledInTestFlight }
            return enabledInProduction
        }
    }
}
