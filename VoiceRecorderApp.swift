//
//  VoiceRecorderApp.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI
import UserNotifications

@main
struct VoiceRecorderApp: App {
    @StateObject private var audioRecorder = AudioRecorderManager()
    @StateObject private var audioPlayer = AudioPlayerManager()
    @StateObject private var fileManager = AudioFileManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioRecorder)
                .environmentObject(audioPlayer)
                .environmentObject(fileManager)
                .environmentObject(notificationManager)
                .onAppear {
                    setupApp()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    handleAppWillEnterForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    handleAppDidEnterBackground()
                }
        }
    }
    
    private func setupApp() {
        // Setup notification categories
        notificationManager.setupNotificationCategories()
        
        // Setup notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
        
        // Setup audio session
        do {
            try AudioSessionManager.shared.configureForPlayback()
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        // Request notification permission
        Task {
            await notificationManager.requestPermission()
        }
    }
    
    private func handleAppWillEnterForeground() {
        // Refresh file list
        fileManager.refreshAudioFiles()
        
        // Check storage usage
        let storageInfo = fileManager.getStorageInfo()
        if storageInfo.usedPercentage > 0.8 {
            notificationManager.scheduleStorageWarning(
                usedSpace: storageInfo.usedSpace,
                totalSpace: storageInfo.totalSpace
            )
        }
    }
    
    private func handleAppDidEnterBackground() {
        // Save any pending changes
        fileManager.saveMetadata()
        
        // Schedule background processing if needed
        BackgroundTaskManager.shared.scheduleBackgroundProcessing()
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case "START_RECORDING":
            // Handle start recording action
            NotificationCenter.default.post(name: .startRecordingFromNotification, object: nil)
            
        case "PLAY_RECORDING":
            // Handle play recording action
            NotificationCenter.default.post(name: .playRecordingFromNotification, object: nil)
            
        case "SHARE_RECORDING":
            // Handle share recording action
            NotificationCenter.default.post(name: .shareRecordingFromNotification, object: nil)
            
        case "OPEN_STORAGE":
            // Handle open storage management
            NotificationCenter.default.post(name: .openStorageManagement, object: nil)
            
        default:
            break
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let startRecordingFromNotification = Notification.Name("startRecordingFromNotification")
    static let playRecordingFromNotification = Notification.Name("playRecordingFromNotification")
    static let shareRecordingFromNotification = Notification.Name("shareRecordingFromNotification")
    static let openStorageManagement = Notification.Name("openStorageManagement")
}
