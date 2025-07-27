//
//  AudioSessionManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import AVFoundation
import UIKit

class AudioSessionManager: ObservableObject {
    static let shared = AudioSessionManager()
    
    @Published var isAudioSessionActive = false
    @Published var currentRoute: AVAudioSession.RouteDescription?
    @Published var isHeadphonesConnected = false
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    private init() {
        setupNotifications()
        updateAudioRoute()
    }
    
    func configureForRecording() throws {
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)
        isAudioSessionActive = true
    }
    
    func configureForPlayback() throws {
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
        isAudioSessionActive = true
    }
    
    func deactivateSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = false
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    func requestRecordPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInterrupted),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }
    
    @objc private func audioRouteChanged(notification: Notification) {
        updateAudioRoute()
        
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        handleRouteChange(reason: reason)
    }
    
    @objc private func audioSessionInterrupted(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        handleInterruption(type: type, userInfo: userInfo)
    }
    
    @objc private func audioSessionMediaServicesReset() {
        // Handle media services reset
        print("Audio session media services were reset")
        
        // Reconfigure audio session
        do {
            try configureForPlayback()
        } catch {
            print("Failed to reconfigure audio session after reset: \(error)")
        }
    }
    
    private func updateAudioRoute() {
        currentRoute = audioSession.currentRoute
        isHeadphonesConnected = checkHeadphonesConnected()
    }
    
    private func checkHeadphonesConnected() -> Bool {
        return audioSession.currentRoute.outputs.contains { output in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(output.portType)
        }
    }
    
    private func handleRouteChange(reason: AVAudioSession.RouteChangeReason) {
        switch reason {
        case .oldDeviceUnavailable:
            // Handle device disconnection (e.g., headphones unplugged)
            NotificationCenter.default.post(name: .audioDeviceDisconnected, object: nil)
            
        case .newDeviceAvailable:
            // Handle new device connection
            NotificationCenter.default.post(name: .audioDeviceConnected, object: nil)
            
        case .categoryChange:
            // Handle category change
            break
            
        default:
            break
        }
    }
    
    private func handleInterruption(type: AVAudioSession.InterruptionType, userInfo: [AnyHashable: Any]) {
        switch type {
        case .began:
            // Audio session interrupted (e.g., phone call)
            NotificationCenter.default.post(name: .audioSessionInterrupted, object: nil)
            
        case .ended:
            // Audio session interruption ended
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Resume audio session
                    NotificationCenter.default.post(name: .audioSessionResumed, object: nil)
                }
            }
            
        @unknown default:
            break
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let audioDeviceConnected = Notification.Name("audioDeviceConnected")
    static let audioDeviceDisconnected = Notification.Name("audioDeviceDisconnected")
    static let audioSessionInterrupted = Notification.Name("audioSessionInterrupted")
    static let audioSessionResumed = Notification.Name("audioSessionResumed")
}
