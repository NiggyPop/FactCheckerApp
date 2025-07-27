//
//  AccessibilityManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import UIKit
import SwiftUI

class AccessibilityManager: ObservableObject {
    @Published var isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
    @Published var preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
    @Published var isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    @Published var isDarkerSystemColorsEnabled = UIAccessibility.isDarkerSystemColorsEnabled
    
    init() {
        setupAccessibilityNotifications()
    }
    
    private func setupAccessibilityNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        }
        
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isDarkerSystemColorsEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        }
    }
    
    func announceFactCheckResult(_ result: FactCheckResult) {
        guard isVoiceOverEnabled else { return }
        
        let announcement = createAccessibilityAnnouncement(for: result)
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    func announceListeningStateChange(isListening: Bool) {
        guard isVoiceOverEnabled else { return }
        
        let announcement = isListening ? "Started listening for speech" : "Stopped listening"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    private func createAccessibilityAnnouncement(for result: FactCheckResult) -> String {
        let veracityText = result.veracity.accessibilityDescription
        let confidenceText = String(format: "%.0f", result.confidence * 100)
        
        return "Fact check complete. Statement is \(veracityText) with \(confidenceText) percent confidence."
    }
}

extension FactVeracity {
    var accessibilityDescription: String {
        switch self {
        case .true:
            return "true"
        case .false:
            return "false"
        case .mixed:
            return "partially true"
        case .unknown:
            return "unverified"
        }
    }
}

// MARK: - Accessibility View Modifiers

struct AccessibleFactCheckButton: ViewModifier {
    let isListening: Bool
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(isListening ? "Stop listening" : "Start listening")
            .accessibilityHint(isListening ? "Stops recording audio for fact checking" : "Starts recording audio for fact checking")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Toggle listening") {
                action()
            }
    }
}

struct AccessibleFactCheckResult: ViewModifier {
    let result: FactCheckResult
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(createAccessibilityLabel())
            .accessibilityValue(createAccessibilityValue())
            .accessibilityAddTraits(.isStaticText)
    }
    
    private func createAccessibilityLabel() -> String {
        return "Fact check result for statement: \(result.statement)"
    }
    
    private func createAccessibilityValue() -> String {
        let veracityText = result.veracity.accessibilityDescription
        let confidenceText = String(format: "%.0f", result.confidence * 100)
        let sourceCount = result.sources.count
        
        return "Result: \(veracityText), Confidence: \(confidenceText) percent, Sources: \(sourceCount)"
    }
}

extension View {
    func accessibleFactCheckButton(isListening: Bool, action: @escaping () -> Void) -> some View {
        modifier(AccessibleFactCheckButton(isListening: isListening, action: action))
    }
    
    func accessibleFactCheckResult(_ result: FactCheckResult) -> some View {
        modifier(AccessibleFactCheckResult(result: result))
    }
}
