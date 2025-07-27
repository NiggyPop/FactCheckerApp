//
//  NoiseReducer.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import AVFoundation
import Accelerate

class NoiseReducer {
    private let fftSetup: FFTSetup
    private let bufferSize: Int = 4096
    private let hopSize: Int = 2048
    private let windowSize: Int = 4096
    
    private var window: [Float]
    private var noiseProfile: [Float]
    private var isNoiseProfileSet = false
    
    init() {
        let log2n = vDSP_Length(log2(Float(bufferSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        // Create Hann window
        window = [Float](repeating: 0, count: windowSize)
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))
        
        noiseProfile = [Float](repeating: 0, count: bufferSize / 2)
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    func reduce(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let inputData = buffer.floatChannelData?[0],
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        
        let frameCount = Int(buffer.frameLength)
        let outputData = outputBuffer.floatChannelData![0]
        
        // If noise profile isn't set, estimate it from the first few frames
        if !isNoiseProfileSet && frameCount >= windowSize {
            estimateNoiseProfile(inputData, frameCount: min(frameCount, windowSize * 4))
            isNoiseProfileSet = true
        }
        
        // Process audio in overlapping windows
        var outputIndex = 0
        
        for windowStart in stride(from: 0, to: frameCount - windowSize, by: hopSize) {
            let windowEnd = min(windowStart + windowSize, frameCount)
            let currentWindowSize = windowEnd - windowStart
            
            if currentWindowSize < windowSize / 2 { break }
            
            // Extract window
            var windowData = [Float](repeating: 0, count: windowSize)
            vDSP_vmul(inputData.advanced(by: windowStart), 1, window, 1, &windowData, 1, vDSP_Length(currentWindowSize))
            
            // Apply noise reduction
            let processedWindow = spectralSubtraction(windowData)
            
            // Overlap-add to output
            let outputEnd = min(outputIndex + currentWindowSize, frameCount)
            let copyLength = outputEnd - outputIndex
            
            if copyLength > 0 {
                vDSP_vadd(outputData.advanced(by: outputIndex), 1, processedWindow, 1, outputData.advanced(by: outputIndex), 1, vDSP_Length(copyLength))
            }
            
            outputIndex += hopSize
        }
        
        outputBuffer.frameLength = buffer.frameLength
        return outputBuffer
    }
    
    private func estimateNoiseProfile(_ data: UnsafePointer<Float>, frameCount: Int) {
        var magnitudeSum = [Float](repeating: 0, count: bufferSize / 2)
        var windowCount = 0
        
        for windowStart in stride(from: 0, to: frameCount - windowSize, by: hopSize) {
            var windowData = [Float](repeating: 0, count: windowSize)
            vDSP_vmul(data.advanced(by: windowStart), 1, window, 1, &windowData, 1, vDSP_Length(windowSize))
            
            let magnitude = computeMagnitudeSpectrum(windowData)
            vDSP_vadd(magnitudeSum, 1, magnitude, 1, &magnitudeSum, 1, vDSP_Length(bufferSize / 2))
            windowCount += 1
        }
        
        // Average the magnitude spectra
        if windowCount > 0 {
            var divisor = Float(windowCount)
            vDSP_vsdiv(magnitudeSum, 1, &divisor, &noiseProfile, 1, vDSP_Length(bufferSize / 2))
        }
    }
    
    private func spectralSubtraction(_ windowData: [Float]) -> [Float] {
        let magnitude = computeMagnitudeSpectrum(windowData)
        let phase = computePhaseSpectrum(windowData)
        
        // Spectral subtraction
        var enhancedMagnitude = [Float](repeating: 0, count: bufferSize / 2)
        let alpha: Float = 2.0 // Over-subtraction factor
        let beta: Float = 0.1  // Spectral floor factor
        
        for i in 0..<bufferSize / 2 {
            let subtracted = magnitude[i] - alpha * noiseProfile[i]
            enhancedMagnitude[i] = max(subtracted, beta * magnitude[i])
        }
        
        // Reconstruct signal
        return reconstructSignal(magnitude: enhancedMagnitude, phase: phase)
    }
    
    private func computeMagnitudeSpectrum(_ data: [Float]) -> [Float] {
        var realParts = [Float](repeating: 0, count: bufferSize / 2)
        var imagParts = [Float](repeating: 0, count: bufferSize / 2)
        var magnitude = [Float](repeating: 0, count: bufferSize / 2)
        
        // Prepare for FFT
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        
        data.withUnsafeBufferPointer { dataPtr in
            dataPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: bufferSize / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(bufferSize / 2))
            }
        }
        
        // Perform FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(bufferSize))), FFTDirection(FFT_FORWARD))
        
        // Compute magnitude
        vDSP_zvmags(&splitComplex, 1, &magnitude, 1, vDSP_Length(bufferSize / 2))
        vDSP_vsqrt(magnitude, 1, &magnitude, 1, vDSP_Length(bufferSize / 2))
        
        return magnitude
    }
    
    private func computePhaseSpectrum(_ data: [Float]) -> [Float] {
        var realParts = [Float](repeating: 0, count: bufferSize / 2)
        var imagParts = [Float](repeating: 0, count: bufferSize / 2)
        var phase = [Float](repeating: 0, count: bufferSize / 2)
        
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        
        data.withUnsafeBufferPointer { dataPtr in
            dataPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: bufferSize / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(bufferSize / 2))
            }
        }
        
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(bufferSize))), FFTDirection(FFT_FORWARD))
        
        // Compute phase
        vDSP_zvphas(&splitComplex, 1, &phase, 1, vDSP_Length(bufferSize / 2))
        
        return phase
    }
    
    private func reconstructSignal(magnitude: [Float], phase: [Float]) -> [Float] {
        var realParts = [Float](repeating: 0, count: bufferSize / 2)
        var imagParts = [Float](repeating: 0, count: bufferSize / 2)
        var result = [Float](repeating: 0, count: windowSize)
        
        // Convert magnitude and phase to complex
        for i in 0..<bufferSize / 2 {
            realParts[i] = magnitude[i] * cos(phase[i])
            imagParts[i] = magnitude[i] * sin(phase[i])
        }
        
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        
        // Inverse FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(bufferSize))), FFTDirection(FFT_INVERSE))
        
        // Convert back to real signal
        result.withUnsafeMutableBufferPointer { resultPtr in
            resultPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: bufferSize / 2) { complexPtr in
                vDSP_ztoc(&splitComplex, 1, complexPtr, 2, vDSP_Length(bufferSize / 2))
            }
        }
        
        // Normalize
        var scale = Float(1.0 / Float(bufferSize))
        vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(windowSize))
        
        return result
    }
}
