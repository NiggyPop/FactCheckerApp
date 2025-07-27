import Foundation
import AVFoundation
import Accelerate

class AudioEffectsProcessor: ObservableObject {
    static let shared = AudioEffectsProcessor()
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    
    private init() {}
    
    // MARK: - Audio Effects
    
    func applyNormalization(to buffer: AVAudioPCMBuffer, targetLevel: Float = -3.0) async throws -> AVAudioPCMBuffer {
        return try await withCheckedThrowingContinuation { continuation in
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: buffer.format,
                frameCapacity: buffer.frameCapacity
            ) else {
                continuation.resume(throwing: AudioProcessingError.bufferCreationFailed)
                return
            }
            
            outputBuffer.frameLength = buffer.frameLength
            
            // Calculate peak level
            var peak: Float = 0
            let channelCount = Int(buffer.format.channelCount)
            
            for channel in 0..<channelCount {
                if let channelData = buffer.floatChannelData?[channel] {
                    var channelPeak: Float = 0
                    vDSP_maxmgv(channelData, 1, &channelPeak, vDSP_Length(buffer.frameLength))
                    peak = max(peak, channelPeak)
                }
            }
            
            // Calculate gain needed to reach target level
            let targetLinear = pow(10, targetLevel / 20)
            let gain = peak > 0 ? targetLinear / peak : 1.0
            
            // Apply gain
            for channel in 0..<channelCount {
                if let inputData = buffer.floatChannelData?[channel],
                   let outputData = outputBuffer.floatChannelData?[channel] {
                    vDSP_vsmul(inputData, 1, &gain, outputData, 1, vDSP_Length(buffer.frameLength))
                }
            }
            
            continuation.resume(returning: outputBuffer)
        }
    }
    
    func applyNoiseReduction(to buffer: AVAudioPCMBuffer, strength: Float = 0.5) async throws -> AVAudioPCMBuffer {
        return try await withCheckedThrowingContinuation { continuation in
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: buffer.format,
                frameCapacity: buffer.frameCapacity
            ) else {
                continuation.resume(throwing: AudioProcessingError.bufferCreationFailed)
                return
            }
            
            outputBuffer.frameLength = buffer.frameLength
            
            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            
            // Simple noise gate implementation
            let threshold: Float = 0.01 * (1.0 - strength)
            let ratio: Float = 1.0 + strength * 9.0 // 1:1 to 10:1 ratio
            
            for channel in 0..<channelCount {
                if let inputData = buffer.floatChannelData?[channel],
                   let outputData = outputBuffer.floatChannelData?[channel] {
                    
                    for i in 0..<frameCount {
                        let sample = inputData[i]
                        let amplitude = abs(sample)
                        
                        if amplitude < threshold {
                            // Apply noise gate
                            outputData[i] = sample * (amplitude / threshold) / ratio
                        } else {
                            outputData[i] = sample
                        }
                    }
                }
            }
            
            continuation.resume(returning: outputBuffer)
        }
    }
    
    func applyEqualizer(to buffer: AVAudioPCMBuffer, settings: EqualizerSettings) async throws -> AVAudioPCMBuffer {
        return try await withCheckedThrowingContinuation { continuation in
            let audioUnit = AVAudioUnitEQ(numberOfBands: settings.bands.count)
            
            // Configure EQ bands
            for (index, band) in settings.bands.enumerated() {
                let eqBand = audioUnit.bands[index]
                eqBand.frequency = band.frequency
                eqBand.gain = band.gain
                eqBand.bandwidth = band.bandwidth
                eqBand.filterType = band.filterType
                eqBand.bypass = false
            }
            
            // Process audio through EQ
            processBufferThroughAudioUnit(buffer, audioUnit: audioUnit) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func applyReverb(to buffer: AVAudioPCMBuffer, settings: ReverbSettings) async throws -> AVAudioPCMBuffer {
        return try await withCheckedThrowingContinuation { continuation in
            let reverbUnit = AVAudioUnitReverb()
            reverbUnit.loadFactoryPreset(settings.preset)
            reverbUnit.wetDryMix = settings.wetDryMix
            
            processBufferThroughAudioUnit(buffer, audioUnit: reverbUnit) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func applyCompression(to buffer: AVAudioPCMBuffer, settings: CompressionSettings) async throws -> AVAudioPCMBuffer {
        return try await withCheckedThrowingContinuation { continuation in
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: buffer.format,
                frameCapacity: buffer.frameCapacity
            ) else {
                continuation.resume(throwing: AudioProcessingError.bufferCreationFailed)
                return
            }
            
            outputBuffer.frameLength = buffer.frameLength
            
            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            
            // Simple compressor implementation
            let threshold = settings.threshold
            let ratio = settings.ratio
            let attack = settings.attack
            let release = settings.release
            let makeupGain = settings.makeupGain
            
            var envelope: Float = 0
            
            for channel in 0..<channelCount {
                if let inputData = buffer.floatChannelData?[channel],
                   let outputData = outputBuffer.floatChannelData?[channel] {
                    
                    for i in 0..<frameCount {
                        let sample = inputData[i]
                        let amplitude = abs(sample)
                        
                        // Envelope follower
                        if amplitude > envelope {
                            envelope += (amplitude - envelope) * attack
                        } else {
                            envelope += (amplitude - envelope) * release
                        }
                        
                        // Compression
                        var gain: Float = 1.0
                        if envelope > threshold {
                            let excess = envelope - threshold
                            let compressedExcess = excess / ratio
                            gain = (threshold + compressedExcess) / envelope
                        }
                        
                        outputData[i] = sample * gain * makeupGain
                    }
                }
            }
            
            continuation.resume(returning: outputBuffer)
        }
    }
    
    func trimSilence(from buffer: AVAudioPCMBuffer, threshold: Float = 0.01) async throws -> AVAudioPCMBuffer {
        return try await withCheckedThrowingContinuation { continuation in
            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            
            var startFrame = 0
            var endFrame = frameCount - 1
            
            // Find start of audio content
            for i in 0..<frameCount {
                var hasSignal = false
                for channel in 0..<channelCount {
                    if let channelData = buffer.floatChannelData?[channel] {
                        if abs(channelData[i]) > threshold {
                            hasSignal = true
                            break
                        }
                    }
                }
                if hasSignal {
                    startFrame = i
                    break
                }
            }
            
            // Find end of audio content
            for i in stride(from: frameCount - 1, through: startFrame, by: -1) {
                var hasSignal = false
                for channel in 0..<channelCount {
                    if let channelData = buffer.floatChannelData?[channel] {
                        if abs(channelData[i]) > threshold {
                            hasSignal = true
                            break
                        }
                    }
                }
                if hasSignal {
                    endFrame = i
                    break
                }
            }
            
            let trimmedLength = endFrame - startFrame + 1
            
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: buffer.format,
                frameCapacity: AVAudioFrameCount(trimmedLength)
            ) else {
                continuation.resume(throwing: AudioProcessingError.bufferCreationFailed)
                return
            }
            
            outputBuffer.frameLength = AVAudioFrameCount(trimmedLength)
            
            // Copy trimmed audio data
            for channel in 0..<channelCount {
                if let inputData = buffer.floatChannelData?[channel],
                   let outputData = outputBuffer.floatChannelData?[channel] {
                    memcpy(outputData, inputData + startFrame, trimmedLength * MemoryLayout<Float>.size)
                }
            }
            
            continuation.resume(returning: outputBuffer)
        }
    }
    
    // MARK: - Batch Processing
    
    func processAudioFile(
        at url: URL,
        effects: [AudioEffect],
        outputURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        isProcessing = true
        processingProgress = 0
        
        defer {
            isProcessing = false
            processingProgress = 0
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let inputFile = try AVAudioFile(forReading: url)
                let outputFile = try AVAudioFile(
                    forWriting: outputURL,
                    settings: inputFile.fileFormat.settings
                )
                
                let bufferSize: AVAudioFrameCount = 4096
                let totalFrames = inputFile.length
                var processedFrames: AVAudioFrameCount = 0
                
                while processedFrames < totalFrames {
                    let framesToRead = min(bufferSize, totalFrames - processedFrames)
                    
                    guard let buffer = AVAudioPCMBuffer(
                        pcmFormat: inputFile.processingFormat,
                        frameCapacity: framesToRead
                    ) else {
                        continuation.resume(throwing: AudioProcessingError.bufferCreationFailed)
                        return
                    }
                    
                    try inputFile.read(into: buffer, frameCount: framesToRead)
                    
                    // Apply effects
                    var processedBuffer = buffer
                    for effect in effects {
                        processedBuffer = try await applyEffect(effect, to: processedBuffer)
                    }
                    
                    try outputFile.write(from: processedBuffer)
                    
                    processedFrames += framesToRead
                    let progress = Double(processedFrames) / Double(totalFrames)
                    
                    await MainActor.run {
                        self.processingProgress = progress
                        progressHandler(progress)
                    }
                }
                
                continuation.resume()
                
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func processBufferThroughAudioUnit(
        _ buffer: AVAudioPCMBuffer,
        audioUnit: AVAudioUnit,
        completion: @escaping (Result<AVAudioPCMBuffer, Error>) -> Void
    ) {
        audioEngine.stop()
        audioEngine.reset()
        
        let playerNode = AVAudioPlayerNode()
        
        audioEngine.attach(playerNode)
        audioEngine.attach(audioUnit)
        
        audioEngine.connect(playerNode, to: audioUnit, format: buffer.format)
        audioEngine.connect(audioUnit, to: audioEngine.mainMixerNode, format: buffer.format)
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        ) else {
            completion(.failure(AudioProcessingError.bufferCreationFailed))
            return
        }
        
        outputBuffer.frameLength = buffer.frameLength
        
        do {
            try audioEngine.start()
            
            playerNode.scheduleBuffer(buffer) {
                // Buffer finished playing
            }
            
            playerNode.play()
            
            // This is a simplified approach - in practice, you'd need to capture the output
            // For now, we'll return the original buffer as a placeholder
            completion(.success(buffer))
            
        } catch {
            completion(.failure(error))
        }
    }
    
    private func applyEffect(_ effect: AudioEffect, to buffer: AVAudioPCMBuffer) async throws -> AVAudioPCMBuffer {
        switch effect {
        case .normalization(let targetLevel):
            return try await applyNormalization(to: buffer, targetLevel: targetLevel)
        case .noiseReduction(let strength):
            return try await applyNoiseReduction(to: buffer, strength: strength)
        case .equalizer(let settings):
            return try await applyEqualizer(to: buffer, settings: settings)
        case .reverb(let settings):
            return try await applyReverb(to: buffer, settings: settings)
        case .compression(let settings):
            return try await applyCompression(to: buffer, settings: settings)
        case .trimSilence(let threshold):
            return try await trimSilence(from: buffer, threshold: threshold)
        }
    }
}

// MARK: - Supporting Types

enum AudioEffect {
    case normalization(targetLevel: Float)
    case noiseReduction(strength: Float)
    case equalizer(settings: EqualizerSettings)
    case reverb(settings: ReverbSettings)
    case compression(settings: CompressionSettings)
    case trimSilence(threshold: Float)
}

struct EqualizerSettings {
    let bands: [EQBand]
    
    static let defaultSettings = EqualizerSettings(bands: [
        EQBand(frequency: 60, gain: 0, bandwidth: 1, filterType: .lowPass),
        EQBand(frequency: 170, gain: 0, bandwidth: 1, filterType: .parametric),
        EQBand(frequency: 350, gain: 0, bandwidth: 1, filterType: .parametric),
        EQBand(frequency: 1000, gain: 0, bandwidth: 1, filterType: .parametric),
        EQBand(frequency: 3500, gain: 0, bandwidth: 1, filterType: .parametric),
        EQBand(frequency: 10000, gain: 0, bandwidth: 1, filterType: .highPass)
    ])
}

struct EQBand {
    let frequency: Float
    let gain: Float
    let bandwidth: Float
    let filterType: AVAudioUnitEQFilterType
}

struct ReverbSettings {
    let preset: AVAudioUnitReverbPreset
    let wetDryMix: Float
    
    static let defaultSettings = ReverbSettings(
        preset: .mediumRoom,
        wetDryMix: 20
    )
}

struct CompressionSettings {
    let threshold: Float
    let ratio: Float
    let attack: Float
    let release: Float
    let makeupGain: Float
    
    static let defaultSettings = CompressionSettings(
        threshold: 0.7,
        ratio: 4.0,
        attack: 0.003,
        release: 0.1,
        makeupGain: 1.0
    )
}

enum AudioProcessingError: Error, LocalizedError {
    case bufferCreationFailed
    case processingFailed
    case invalidInput
    case audioEngineError
    
    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .processingFailed:
            return "Audio processing failed"
        case .invalidInput:
            return "Invalid input parameters"
        case .audioEngineError:
            return "Audio engine error"
        }
    }
}
