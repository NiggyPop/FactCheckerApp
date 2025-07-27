//
//  LocalizationManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    @Published var currentLanguage: String = Locale.current.languageCode ?? "en"
    
    private var bundle: Bundle = Bundle.main
    
    init() {
        setLanguage(currentLanguage)
    }
    
    func setLanguage(_ language: String) {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            self.bundle = Bundle.main
            return
        }
        
        self.bundle = bundle
        self.currentLanguage = language
        
        // Save preference
        UserDefaults.standard.set(language, forKey: "selected_language")
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    func localizedString(for key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: bundle, comment: comment)
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - Localized String Helper
func L(_ key: String, comment: String = "") -> String {
    return NSLocalizedString(key, comment: comment)
}

// MARK: - SwiftUI Localization Extension
extension Text {
    init(localized key: String, comment: String = "") {
        self.init(L(key, comment: comment))
    }
}
