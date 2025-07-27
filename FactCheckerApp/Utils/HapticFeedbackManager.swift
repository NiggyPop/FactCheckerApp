//
//  HapticFeedbackManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import UIKit

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    
    private init() {
        prepareGenerators()
    }
    
    private func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selection.prepare()
    }
    
    func recordingStarted() {
        guard isHapticEnabled else { return }
        impactMedium.impactOccurred()
    }
    
    func recordingStopped() {
        guard isHapticEnabled else { return }
        impactHeavy.impactOccurred()
    }
    
    func playbackStarted() {
        guard isHapticEnabled else { return }
        impactLight.impactOccurred()
    }
    
    func playbackStopped() {
        guard isHapticEnabled else { return }
        impactLight.impactOccurred()
    }
    
    func buttonTapped() {
        guard isHapticEnabled else { return }
        selection.selectionChanged()
    }
    
    func effectApplied() {
        guard isHapticEnabled else { return }
        notification.notificationOccurred(.success)
    }
    
    func errorOccurred() {
        guard isHapticEnabled else { return }
        notification.notificationOccurred(.error)
    }
    
    func warningOccurred() {
        guard isHapticEnabled else { return }
        notification.notificationOccurred(.warning)
    }
    
    func sliderValueChanged() {
        guard isHapticEnabled else { return }
        impactLight.impactOccurred(intensity: 0.5)
    }
    
    func fileDeleted() {
        guard isHapticEnabled else { return }
        impactMedium.impactOccurred()
    }
    
    func longPressDetected() {
        guard isHapticEnabled else { return }
        impactHeavy.impactOccurred()
    }
    
    private var isHapticEnabled: Bool {
        UserDefaults.standard.bool(forKey: "enableHapticFeedback")
    }
}
