//
//  AudioSessionManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import AVFoundation
import CallKit
import MediaPlayer

class AudioSessionManager: NSObject, ObservableObject {
    static let shared = AudioSessionManager()
    
    @Published var isAudioSessionActive = false
    @Published var currentRoute: AVAudioSession.RouteDescription?
    @Published var isHeadphonesConnected = false
    @Published var isBluetoothConnected = false
    @Published var availableInputs: [AVAudioSessionPortDescription] = []
    @Published var currentInput: AVAudioSessionPortDescription?
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioSessionObservers: [NSObjectProtocol] = []
    
    override init() {
        super.init()
        setupAudioSession()
        setupNotificationObservers()
    }
    
    deinit {
        audioSessionObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            // Configure audio session for recording and playback
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [
                    .defaultToSpeaker,
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .allowAirPlay,
                    .duckOthers
                ]
            )
            
            // Set preferred sample rate and buffer duration
            try audioSession.setPreferredSampleRate(44100)
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms for low latency
            
            updateAudioRouteInfo()
            
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupNotificationObservers() {
        let notificationCenter = NotificationCenter.default
        
        // Audio route change
        let routeChangeObserver = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
        audioSessionObservers.append(routeChangeObserver)
        
        // Audio interruption
        let interruptionObserver = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
        audioSessionObservers.append(interruptionObserver)
        
        // Media services reset
        let mediaServicesResetObserver = notificationCenter.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMediaServicesReset()
        }
        audioSessionObservers.append(mediaServicesResetObserver)
        
        // Silence secondary audio hint
        let silenceHintObserver = notificationCenter.addObserver(
            forName: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSilenceSecondaryAudioHint(notification)
        }
        audioSessionObservers.append(silenceHintObserver)
    }
    
    // MARK: - Public Methods
    
    func activateSession() async throws {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try audioSession.setActive(true)
                DispatchQueue.main.async {
                    self.isAudioSessionActive = true
                    self.updateAudioRouteInfo()
                }
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func deactivateSession() async throws {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                DispatchQueue.main.async {
                    self.isAudioSessionActive = false
                }
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func requestRecordPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func setPreferredInput(_ input: AVAudioSessionPortDescription?) throws {
        try audioSession.setPreferredInput(input)
        updateAudioRouteInfo()
    }
    
    func overrideOutputAudioPort(_ portOverride: AVAudioSession.PortOverride) throws {
        try audioSession.overrideOutputAudioPort(portOverride)
        updateAudioRouteInfo()
    }
    
    func configureForRecording() throws {
        try audioSession.setCategory(
            .record,
            mode: .measurement,
            options: [.duckOthers, .defaultToSpeaker]
        )
        try audioSession.setActive(true)
        updateAudioRouteInfo()
    }
    
    func configureForPlayback() throws {
        try audioSession.setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.duckOthers]
        )
        try audioSession.setActive(true)
        updateAudioRouteInfo()
    }
    
    func configureForPlayAndRecord() throws {
        try audioSession.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .duckOthers
            ]
        )
        try audioSession.setActive(true)
        updateAudioRouteInfo()
    }
    
    // MARK: - Audio Route Management
    
    private func updateAudioRouteInfo() {
        DispatchQueue.main.async {
            self.currentRoute = self.audioSession.currentRoute
            self.availableInputs = self.audioSession.availableInputs ?? []
            self.currentInput = self.audioSession.preferredInput
            
            // Check for specific device types
            self.isHeadphonesConnected = self.currentRoute?.outputs.contains { output in
                [.headphones, .bluetoothHFP, .bluetoothA2DP].contains(output.portType)
            } ?? false
            
            self.isBluetoothConnected = self.currentRoute?.outputs.contains { output in
                [.bluetoothHFP, .bluetoothA2DP, .bluetoothLE].contains(output.portType)
            } ?? false
        }
    }
    
    // MARK: - Notification Handlers
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        updateAudioRouteInfo()
        
        switch reason {
        case .newDeviceAvailable:
            print("New audio device available")
            NotificationCenter.default.post(name: .audioDeviceConnected, object: nil)
            
        case .oldDeviceUnavailable:
            print("Audio device disconnected")
            NotificationCenter.default.post(name: .audioDeviceDisconnected, object: nil)
            
        case .categoryChange:
            print("Audio session category changed")
            
        case .override:
            print("Audio route override")
            
        case .wakeFromSleep:
            print("Audio session wake from sleep")
            
        case .noSuitableRouteForCategory:
            print("No suitable route for category")
            
        case .routeConfigurationChange:
            print("Route configuration changed")
            
        @unknown default:
            print("Unknown route change reason")
        }
    }
    
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("Audio interruption began")
            NotificationCenter.default.post(name: .audioInterruptionBegan, object: nil)
            
        case .ended:
            print("Audio interruption ended")
            
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Resume audio session
                    do {
                        try audioSession.setActive(true)
                        NotificationCenter.default.post(name: .audioInterruptionEnded, object: true)
                    } catch {
                        print("Failed to resume audio session: \(error)")
                        NotificationCenter.default.post(name: .audioInterruptionEnded, object: false)
                    }
                } else {
                    NotificationCenter.default.post(name: .audioInterruptionEnded, object: false)
                }
            }
            
        @unknown default:
            break
        }
    }
    
    private func handleMediaServicesReset() {
        print("Media services were reset")
        
        // Reconfigure audio session
        setupAudioSession()
        
        // Notify observers
        NotificationCenter.default.post(name: .audioServicesReset, object: nil)
    }
    
    private func handleSilenceSecondaryAudioHint(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .begin:
            print("Should silence secondary audio")
            
        case .end:
            print("Can resume secondary audio")
            
        @unknown default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let audioDeviceConnected = Notification.Name("audioDeviceConnected")
    static let audioDeviceDisconnected = Notification.Name("audioDeviceDisconnected")
    static let audioInterruptionBegan = Notification.Name("audioInterruptionBegan")
    static let audioInterruptionEnded = Notification.Name("audioInterruptionEnded")
    static let audioServicesReset = Notification.Name("audioServicesReset")
}
