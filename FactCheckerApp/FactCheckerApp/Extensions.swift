//
//  Keys.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI
import Foundation

// MARK: - Color Extensions
extension Color {
    static let factCheckGreen = Color(red: 0.2, green: 0.8, blue: 0.2)
    static let factCheckRed = Color(red: 0.9, green: 0.2, blue: 0.2)
    static let factCheckOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let factCheckGray = Color(red: 0.6, green: 0.6, blue: 0.6)
}

// MARK: - String Extensions
extension String {
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    func truncated(to length: Int) -> String {
        if self.count <= length {
            return self
        } else {
            return String(self.prefix(length)) + "..."
        }
    }
    
    var wordCount: Int {
        return self.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

// MARK: - Date Extensions
extension Date {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    var isThisWeek: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

// MARK: - View Extensions
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    func conditionalModifier<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        Group {
            if condition {
                transform(self)
            } else {
                self
            }
        }
    }
}

// MARK: - Array Extensions
extension Array where Element == FactCheckResult {
    var accuracyRate: Double {
        guard !isEmpty else { return 0 }
        let trueCount = filter { $0.veracity == .true }.count
        return Double(trueCount) / Double(count)
    }
    
    var averageConfidence: Double {
        guard !isEmpty else { return 0 }
        let totalConfidence = reduce(0) { $0 + $1.confidence }
        return totalConfidence / Double(count)
    }
}

// MARK: - UserDefaults Extensions
extension UserDefaults {
    private enum Keys {
        static let isFirstLaunch = "isFirstLaunch"
        static let onboardingCompleted = "onboardingCompleted"
        static let appTheme = "appTheme"
        static let enableHapticFeedback = "enableHapticFeedback"
        static let enableNotifications = "enableNotifications"
        static let confidenceThreshold = "confidenceThreshold"
        static let maxSourcesPerCheck = "maxSourcesPerCheck"
        static let audioSensitivity = "audioSensitivity"
        static let speechRecognitionLanguage = "speechRecognitionLanguage"
        static let dataRetentionPeriod = "dataRetentionPeriod"
    }
    
    var isFirstLaunch: Bool {
        get { !bool(forKey: Keys.onboardingCompleted) }
        set { set(!newValue, forKey: Keys.onboardingCompleted) }
    }
    
    var appTheme: AppTheme {
        get {
            if let rawValue = string(forKey: Keys.appTheme),
               let theme = AppTheme(rawValue: rawValue) {
                return theme
            }
            return .system
        }
        set { set(newValue.rawValue, forKey: Keys.appTheme) }
    }
    
    var enableHapticFeedback: Bool {
        get { object(forKey: Keys.enableHapticFeedback) as? Bool ?? true }
        set { set(newValue, forKey: Keys.enableHapticFeedback) }
    }
    
    var confidenceThreshold: Double {
        get { object(forKey: Keys.confidenceThreshold) as? Double ?? 0.7 }
        set { set(newValue, forKey: Keys.confidenceThreshold) }
    }
    
    var maxSourcesPerCheck: Int {
        get { object(forKey: Keys.maxSourcesPerCheck) as? Int ?? 5 }
        set { set(newValue, forKey: Keys.maxSourcesPerCheck) }
    }
}
