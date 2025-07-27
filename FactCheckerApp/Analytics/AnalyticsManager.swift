//
//  AnalyticsManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import Combine

class AnalyticsManager: ObservableObject {
    private let isEnabled = AppConfig.Analytics.isEnabled
    private var eventQueue: [AnalyticsEvent] = []
    private let maxQueueSize = 100
    private let flushInterval: TimeInterval = 30.0
    private var flushTimer: Timer?
    
    init() {
        setupPeriodicFlush()
    }
    
    deinit {
        flushTimer?.invalidate()
        flushEvents()
    }
    
    // MARK: - Event Tracking
    
    func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        
        eventQueue.append(event)
        
        if eventQueue.count >= maxQueueSize {
            flushEvents()
        }
    }
    
    func trackFactCheck(statement: String, result: FactCheckResult, processingTime: TimeInterval) {
        let event = AnalyticsEvent(
            name: "fact_check_completed",
            parameters: [
                "statement_length": statement.count,
                "veracity": result.veracity.rawValue,
                "confidence": result.confidence,
                "source_count": result.sources.count,
                "processing_time": processingTime,
                "claim_type": result.claimType.rawValue
            ]
        )
        track(event)
    }
    
    func trackSpeakerIdentification(speakerId: String?, confidence: Double) {
        let event = AnalyticsEvent(
            name: "speaker_identified",
            parameters: [
                "speaker_identified": speakerId != nil,
                "confidence": confidence
            ]
        )
        track(event)
    }
    
    func trackUserAction(_ action: UserAction, context: [String: Any] = [:]) {
        let event = AnalyticsEvent(
            name: "user_action",
            parameters: [
                "action": action.rawValue,
                "context": context
            ]
        )
        track(event)
    }
    
    func trackError(_ error: Error, context: String) {
        let event = AnalyticsEvent(
            name: "error_occurred",
            parameters: [
                "error_type": String(describing: type(of: error)),
                "error_description": error.localizedDescription,
                "context": context
            ]
        )
        track(event)
    }
    
    func trackPerformance(operation: String, duration: TimeInterval, success: Bool) {
        let event = AnalyticsEvent(
            name: "performance_metric",
            parameters: [
                "operation": operation,
                "duration": duration,
                "success": success
            ]
        )
        track(event)
    }
    
    // MARK: - Private Methods
    
    private func setupPeriodicFlush() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { _ in
            self.flushEvents()
        }
    }
    
    private func flushEvents() {
        guard !eventQueue.isEmpty else { return }
        
        let eventsToFlush = eventQueue
        eventQueue.removeAll()
        
        // Send events to analytics service
        sendEvents(eventsToFlush)
    }
    
    private func sendEvents(_ events: [AnalyticsEvent]) {
        // Implementation would depend on your analytics provider
        // Example: Firebase Analytics, Mixpanel, etc.
        
        for event in events {
            print("📊 Analytics: \(event.name) - \(event.parameters)")
        }
    }
}

struct AnalyticsEvent {
    let name: String
    let parameters: [String: Any]
    let timestamp: Date
    
    init(name: String, parameters: [String: Any]) {
        self.name = name
        self.parameters = parameters
        self.timestamp = Date()
    }
}

enum UserAction: String, CaseIterable {
    case startListening = "start_listening"
    case stopListening = "stop_listening"
    case viewHistory = "view_history"
    case exportData = "export_data"
    case addSpeaker = "add_speaker"
    case changeSettings = "change_settings"
    case shareResult = "share_result"
    case viewStatistics = "view_statistics"
}
