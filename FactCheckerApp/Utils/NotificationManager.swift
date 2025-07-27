//
//  NotificationManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import UserNotifications
import UIKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func scheduleRecordingReminder(title: String, body: String, date: Date) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "RECORDING_REMINDER"
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "recording_reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    func scheduleRecordingCompletion(fileName: String, duration: TimeInterval) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Recording Complete"
        content.body = "'\(fileName)' has been saved (\(AudioFileInfo.formatDuration(duration)))"
        content.sound = .default
        content.categoryIdentifier = "RECORDING_COMPLETE"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "recording_complete_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule completion notification: \(error)")
            }
        }
    }
    
    func scheduleStorageWarning(usedSpace: Int64, totalSpace: Int64) {
        guard isAuthorized else { return }
        
        let usedPercentage = Double(usedSpace) / Double(totalSpace) * 100
        
        let content = UNMutableNotificationContent()
        content.title = "Storage Warning"
        content.body = "Voice recordings are using \(Int(usedPercentage))% of your storage. Consider cleaning up old recordings."
        content.sound = .default
        content.categoryIdentifier = "STORAGE_WARNING"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "storage_warning_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule storage warning: \(error)")
            }
        }
    }
    
    func setupNotificationCategories() {
        let recordingReminderCategory = UNNotificationCategory(
            identifier: "RECORDING_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "START_RECORDING",
                    title: "Start Recording",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "SNOOZE",
                    title: "Remind Later",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let recordingCompleteCategory = UNNotificationCategory(
            identifier: "RECORDING_COMPLETE",
            actions: [
                UNNotificationAction(
                    identifier: "PLAY_RECORDING",
                    title: "Play",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "SHARE_RECORDING",
                    title: "Share",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let storageWarningCategory = UNNotificationCategory(
            identifier: "STORAGE_WARNING",
            actions: [
                UNNotificationAction(
                    identifier: "OPEN_STORAGE",
                    title: "Manage Storage",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "Dismiss",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            recordingReminderCategory,
            recordingCompleteCategory,
            storageWarningCategory
        ])
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
}
