//
//  SpeechRecognitionService.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognitionService: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var currentTranscript = ""
    @Published var lastProcessedTranscript = ""
    @Published var newContent = ""
    @Published var error: Error?
    @Published var recognitionConfidence: Double = 0.0
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Transcript management
    private var transcriptSegments: [TranscriptSegment] = []
    private var lastFactCheckTime = Date()
    private var minimumSegmentLength = 10
    private var factCheckCooldown: TimeInterval = 2.0
    
    // Audio data for speaker identification
    private var audioDataSubject = PassthroughSubject<[Float], Never>()
    var audioDataPublisher: AnyPublisher<[Float], Never> {
        audioDataSubject.eraseToAnyPublisher()
    }
    
    // New content detection
    private var newContentSubject = PassthroughSubject<String, Never>()
    var newContentPublisher: AnyPublisher<String, Never> {
        newContentSubject.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
        }
    }
    
    func startListening() {
        guard !isListening else { return }
        guard speechRecognizer?.isAvailable == true else {
            error = SpeechRecognitionError.recognizerNotAvailable
            return
        }
        
        resetTranscriptState()
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.processTranscriptionResult(result)
                }
                
                if let error = error {
                    self?.error = error
                    self?.stopListening()
                }
            }
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            let audioData = self?.extractAudioData(from: buffer) ?? []
            if !audioData.isEmpty {
                self?.audioDataSubject.send(audioData)
            }
        }
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isListening = true
                self.error = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isListening = false
        }
        
        processRemainingContent()
    }
    
    private func processTranscriptionResult(_ result: SFSpeechRecognitionResult) {
        let newTranscript = result.bestTranscription.formattedString
        let confidence = result.bestTranscription.segments.last?.confidence ?? 0.0
        
        currentTranscript = newTranscript
        recognitionConfidence = Double(confidence)
        
        let extractedNewContent = extractNewContent(from: newTranscript)
        
        if !extractedNewContent.isEmpty {
            newContent = extractedNewContent
            
            if shouldTriggerFactCheck(newContent: extractedNewContent) {
                triggerFactCheckForNewContent(extractedNewContent)
            }
        }
    }
    
    private func extractNewContent(from fullTranscript: String) -> String {
        if fullTranscript.hasPrefix(lastProcessedTranscript) {
            let startIndex = fullTranscript.index(fullTranscript.startIndex, offsetBy: lastProcessedTranscript.count)
            return String(fullTranscript[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return findTranscriptDifference(old: lastProcessedTranscript, new: fullTranscript)
    }
    
    private func findTranscriptDifference(old: String, new: String) -> String {
        let oldWords = old.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let newWords = new.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        if newWords.count <= oldWords.count {
            return ""
        }
        
        let newContentWords = Array(newWords[oldWords.count...])
        return newContentWords.joined(separator: " ")
    }
    
    private func shouldTriggerFactCheck(newContent: String) -> Bool {
        let words = newContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let timeSinceLastCheck = Date().timeIntervalSince(lastFactCheckTime)
        
        return words.count >= minimumSegmentLength &&
               timeSinceLastCheck >= factCheckCooldown &&
               containsFactualClaim(newContent)
    }
    
    private func containsFactualClaim(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Skip questions
        if text.hasSuffix("?") || lowercased.hasPrefix("what") || lowercased.hasPrefix("how") {
            return false
        }
        
        // Skip conversational filler
        let fillerPhrases = ["you know", "i mean", "like i said", "anyway"]
        if fillerPhrases.contains(where: lowercased.contains) && text.components(separatedBy: .whitespacesAndNewlines).count < 8 {
            return false
        }
        
        // Look for factual indicators
        let factualIndicators = [
            "percent", "%", "million", "billion", "according to", "studies show",
            "research indicates", "data shows", "statistics", "evidence",
            "in 19", "in 20", "years ago", "more than", "less than"
        ]
        
        return factualIndicators.contains { lowercased.contains($0) }
    }
    
    private func triggerFactCheckForNewContent(_ content: String) {
        let segment = TranscriptSegment(
            content: content,
            timestamp: Date(),
            confidence: recognitionConfidence
        )
        
        transcriptSegments.append(segment)
        lastFactCheckTime = Date()
        
        newContentSubject.send(content)
        lastProcessedTranscript = currentTranscript
    }
    
    private func processRemainingContent() {
        let remainingContent = extractNewContent(from: currentTranscript)
        if !remainingContent.isEmpty && containsFactualClaim(remainingContent) {
            triggerFactCheckForNewContent(remainingContent)
        }
    }
    
    func resetTranscriptState() {
        DispatchQueue.main.async {
            self.currentTranscript = ""
            self.lastProcessedTranscript = ""
            self.newContent = ""
            self.transcriptSegments.removeAll()
            self.lastFactCheckTime = Date()
            self.recognitionConfidence = 0.0
        }
    }
    
    private func extractAudioData(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let frameLength = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData, count: frameLength))
    }
    
    func setMinimumSegmentLength(_ length: Int) {
        minimumSegmentLength = max(5, length)
    }
    
    func setFactCheckCooldown(_ cooldown: TimeInterval) {
        factCheckCooldown = max(1.0, cooldown)
    }
    
    func getUnprocessedSegments() -> [TranscriptSegment] {
        return transcriptSegments.filter { !$0.processed }
    }
    
    func markSegmentAsProcessed(_ segmentId: UUID) {
        if let index = transcriptSegments.firstIndex(where: { $0.id == segmentId }) {
            transcriptSegments[index].processed = true
        }
    }
}

enum SpeechRecognitionError: Error, LocalizedError {
    case recognizerNotAvailable
    case audioEngineError
    case recognitionFailed
    
    var errorDescription: String? {
        switch self {
        case .recognizerNotAvailable:
            return "Speech recognizer is not available"
        case .audioEngineError:
            return "Audio engine failed to start"
        case .recognitionFailed:
            return "Speech recognition failed"
        }
    }
}
