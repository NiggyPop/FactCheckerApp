//
//  AdvancedAudioProcessor.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import AVFoundation
import Speech
import Accelerate
import Combine

class AdvancedAudioProcessor: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var transcriptionText = ""
    @Published var speakerIdentification: SpeakerIdentification?
    @Published var audioQuality: AudioQuality = .good
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioSession = AVAudioSession.sharedInstance()
    
    private var audioBuffer: AVAudioPCMBuffer?
    private var noiseReducer: NoiseReducer
    private var speakerAnalyzer: SpeakerAnalyzer
    private var audioEnhancer: AudioEnhancer
    
    private let sampleRate: Double = 44100
    private let bufferSize: AVAudioFrameCount = 4096
    
    enum AudioQuality {
        case poor, fair, good, excellent
        
        var description: String {
            switch self {
            case .poor: return L("audio_quality_poor")
            case .fair: return L("audio_quality_fair")
            case .good: return L("audio_quality_good")
            case .excellent: return L("audio_quality_excellent")
            }
        }
        
        var color: UIColor {
            switch self {
            case .poor: return .systemRed
            case .fair: return .systemOrange
            case .good: return .systemGreen
            case .excellent: return .systemBlue
            }
        }
    }
    
    override init() {
        self.noiseReducer = NoiseReducer()
        self.speakerAnalyzer = SpeakerAnalyzer()
        self.audioEnhancer = AudioEnhancer()
        
        super.init()
        
        setupAudioSession()
        setupSpeechRecognition()
        setupAudioEngine()
    }
    
    // MARK: - Public Methods
    
    func startRecording() async throws {
        guard !isRecording else { return }
        
        try await requestPermissions()
        
        // Reset previous session
        stopRecording()
        
        // Configure audio session
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Setup recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw AudioProcessingError.recognitionSetupFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = UserDefaults.standard.bool(forKey: "local_processing_only")
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result, error: error)
        }
        
        // Start audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        try? audioSession.setActive(false)
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }
    }
    
    func processAudioFile(at url: URL) async throws -> AudioProcessingResult {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioProcessingError.bufferCreationFailed
        }
        
        try audioFile.read(into: buffer)
        
        // Process audio
        let enhancedBuffer = audioEnhancer.enhance(buffer)
        let denoisedBuffer = noiseReducer.reduce(enhancedBuffer)
        
        // Analyze speaker
        let speakerID = await speakerAnalyzer.identifySpeaker(from: denoisedBuffer)
        
        // Transcribe
        let transcription = try await transcribeBuffer(denoisedBuffer)
        
        // Analyze quality
        let quality = analyzeAudioQuality(denoisedBuffer)
        
        return AudioProcessingResult(
            transcription: transcription,
            speakerIdentification: speakerID,
            audioQuality: quality,
            duration: Double(frameCount) / format.sampleRate
        )
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    private func setupSpeechRecognition() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        speechRecognizer?.delegate = self
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
    }
    
    private func requestPermissions() async throws {
        // Request microphone permission
        let microphoneStatus = await AVAudioSession.sharedInstance().requestRecordPermission()
        guard microphoneStatus else {
            throw AudioProcessingError.microphonePermissionDenied
        }
        
        // Request speech recognition permission
        let speechStatus = await SFSpeechRecognizer.requestAuthorization()
        guard speechStatus == .authorized else {
            throw AudioProcessingError.speechRecognitionPermissionDenied
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Calculate audio level
        let level = calculateAudioLevel(buffer)
        DispatchQueue.main.async {
            self.audioLevel = level
        }
        
        // Enhance audio quality
        let enhancedBuffer = audioEnhancer.enhance(buffer)
        
        // Reduce noise
        let cleanBuffer = noiseReducer.reduce(enhancedBuffer)
        
        // Analyze audio quality
        let quality = analyzeAudioQuality(cleanBuffer)
        DispatchQueue.main.async {
            self.audioQuality = quality
        }
        
        // Send to speech recognition
        recognitionRequest?.append(cleanBuffer)
        
        // Analyze speaker (async)
        Task {
            let speakerID = await speakerAnalyzer.identifySpeaker(from: cleanBuffer)
            DispatchQueue.main.async {
                self.speakerIdentification = speakerID
            }
        }
    }
    
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("Speech recognition error: \(error)")
            return
        }
        
        guard let result = result else { return }
        
        DispatchQueue.main.async {
            self.transcriptionText = result.bestTranscription.formattedString
        }
    }
    
    private func calculateAudioLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        
        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0.0
        
        for i in 0..<frameCount {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameCount)
        return min(average * 10, 1.0) // Normalize and cap at 1.0
    }
    
    private func analyzeAudioQuality(_ buffer: AVAudioPCMBuffer) -> AudioQuality {
        guard let channelData = buffer.floatChannelData?[0] else { return .poor }
        
        let frameCount = Int(buffer.frameLength)
        
        // Calculate signal-to-noise ratio
        var signalPower: Float = 0.0
        var noisePower: Float = 0.0
        
        for i in 0..<frameCount {
            let sample = channelData[i]
            signalPower += sample * sample
            
            // Simple noise estimation (could be more sophisticated)
            if abs(sample) < 0.01 {
                noisePower += sample * sample
            }
        }
        
        signalPower /= Float(frameCount)
        noisePower /= Float(frameCount)
        
        let snr = signalPower / max(noisePower, 0.0001)
        let snrDB = 10 * log10(snr)
        
        switch snrDB {
        case 30...:
            return .excellent
        case 20..<30:
            return .good
        case 10..<20:
            return .fair
        default:
            return .poor
        }
    }
    
    private func transcribeBuffer(_ buffer: AVAudioPCMBuffer) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.append(buffer)
            request.endAudio()
            
            speechRecognizer?.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension AdvancedAudioProcessor: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        // Handle availability changes
        if !available {
            stopRecording()
        }
    }
}

// MARK: - Supporting Types

enum AudioProcessingError: Error, LocalizedError {
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case recognitionSetupFailed
    case bufferCreationFailed
    case audioEngineStartFailed
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return L("error_microphone_permission")
        case .speechRecognitionPermissionDenied:
            return L("error_speech_recognition_permission")
        case .recognitionSetupFailed:
            return L("error_recognition_setup")
        case .bufferCreationFailed:
            return L("error_buffer_creation")
        case .audioEngineStartFailed:
            return L("error_audio_engine_start")
        }
    }
}

struct AudioProcessingResult {
    let transcription: String
    let speakerIdentification: SpeakerIdentification?
    let audioQuality: AdvancedAudioProcessor.AudioQuality
    let duration: Double
}

struct SpeakerIdentification {
    let speakerID: String
    let confidence: Float
    let voiceCharacteristics: VoiceCharacteristics
}

struct VoiceCharacteristics {
    let pitch: Float
    let tempo: Float
    let volume: Float
    let accent: String?
}
