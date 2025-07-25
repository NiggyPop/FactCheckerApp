//
//  FactCheckApp.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI

@main
struct FactCheckApp: App {
    @StateObject private var coordinator = FactCheckCoordinator()
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .environmentObject(settingsManager)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Configure audio session
        configureAudioSession()
        
        // Setup background tasks
        setupBackgroundTasks()
        
        // Apply theme
        applyTheme()
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func setupBackgroundTasks() {
        // Register background tasks for processing
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.factcheck.background-processing", using: nil) { task in
            handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
    }
    
    private func handleBackgroundProcessing(task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform background fact-checking tasks
        coordinator.performBackgroundTasks { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    private func applyTheme() {
        switch settingsManager.appTheme {
        case .light:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .light
        case .dark:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .dark
        case .system:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .unspecified
        }
    }
}
