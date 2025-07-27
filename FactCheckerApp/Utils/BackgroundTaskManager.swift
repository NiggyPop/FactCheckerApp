//
//  BackgroundTaskManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import UIKit
import BackgroundTasks

class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let backgroundTaskIdentifier = "com.voicerecorder.processing"
    
    private init() {
        registerBackgroundTasks()
    }
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
    }
    
    func beginBackgroundTask(name: String = "Audio Processing") {
        endBackgroundTask() // End any existing task
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            self.endBackgroundTask()
        }
    }
    
    func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1 * 60) // 1 minute from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background processing: \(error)")
        }
    }
    
    private func handleBackgroundProcessing(task: BGProcessingTask) {
        // Schedule the next background processing task
        scheduleBackgroundProcessing()
        
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform background processing
        Task {
            await performBackgroundProcessing()
            task.setTaskCompleted(success: true)
        }
    }
    
    private func performBackgroundProcessing() async {
        // Perform any necessary background processing
        // For example: cleanup temporary files, process pending audio effects, etc.
        
        AudioFileManager.shared.cleanupTemporaryFiles()
        
        // Process any pending audio effects
        await AudioEffectsProcessor.shared.processQueuedEffects()
    }
}
