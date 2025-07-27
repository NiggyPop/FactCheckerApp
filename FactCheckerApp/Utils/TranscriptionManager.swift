//
//  TranscriptionManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import Speech
import AVFoundation

class TranscriptionManager: ObservableObject {
    @Published var isAvailable = false
    
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let speechRecognizer = SFSpeechRecognizer()
    
    init() {
        checkAvailability()
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion(true)
                case .denied, .restricted, .notDetermined:
                    completion(false)
                @unknown default:
                    completion(false)
                }
            }
        }
    }
    
    func transcribeAudio(
        url: URL,
        language: String,
        completion: @escaping (Result<String, Error>) -> Void,
        progressHandler: @escaping (Double) -> Void
    ) {
        // Cancel any ongoing transcription
        cancelTranscription()
        
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)) else {
            completion(.failure(TranscriptionError.recognizerNotAvailable))
            return
        }
        
        guard recognizer.isAvailable else {
            completion(.failure(TranscriptionError.recognizerNotAvailable))
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        
        // Get audio duration for progress calculation
        let asset = AVAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        var lastProgressTime: TimeInterval = 0
        
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result = result {
                // Calculate progress based on recognized speech timing
                if let lastSegment = result.bestTranscription.segments.last {
                    let currentTime = lastSegment.timestamp + lastSegment.duration
                    if currentTime > lastProgressTime {
                        lastProgressTime = currentTime
                        let progress = min(currentTime / duration, 1.0)
                        progressHandler(progress)
                    }
                }
                
                if result.isFinal {
                    completion(.success(result.bestTranscription.formattedString))
                }
            }
            
            if let error = error {
                completion(.failure(error))
            }
        }
    }
    
    func transcribeAudioWithTimestamps(
        url: URL,
        language: String,
        completion: @escaping (Result<[TranscriptionSegment], Error>) -> Void
    ) {
        cancelTranscription()
        
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)) else {
            completion(.failure(TranscriptionError.recognizerNotAvailable))
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result = result, result.isFinal {
                let segments = result.bestTranscription.segments.map { segment in
                    TranscriptionSegment(
                        text: segment.substring,
                        startTime: segment.timestamp,
                        duration: segment.duration,
                        confidence: segment.confidence
                    )
                }
                completion(.success(segments))
            }
            
            if let error = error {
                completion(.failure(error))
            }
        }
    }
    
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    private func checkAvailability() {
        isAvailable = SFSpeechRecognizer.authorizationStatus() == .authorized &&
                     speechRecognizer?.isAvailable == true
    }
}

struct TranscriptionSegment {
    let text: String
    let startTime: TimeInterval
    let duration: TimeInterval
    let confidence: Float
    
    var endTime: TimeInterval {
        return startTime + duration
    }
}

enum TranscriptionError: LocalizedError {
    case recognizerNotAvailable
    case audioFileNotFound
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .recognizerNotAvailable:
            return "Speech recognizer is not available"
        case .audioFileNotFound:
            return "Audio file not found"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}
