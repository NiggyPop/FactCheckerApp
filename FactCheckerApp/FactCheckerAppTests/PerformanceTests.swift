//
//  PerformanceTests.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import XCTest
@testable import FactCheckPro

class PerformanceTests: XCTestCase {
    var coordinator: FactCheckCoordinator!
    
    override func setUpWithError() throws {
        coordinator = FactCheckCoordinator()
    }
    
    override func tearDownWithError() throws {
        coordinator = nil
    }
    
    func testFactCheckPerformance() throws {
        let statements = [
            "The Earth is round",
            "Water boils at 100 degrees Celsius",
            "The capital of France is Paris",
            "There are 24 hours in a day",
            "The speed of light is 299,792,458 meters per second"
        ]
        
        measure {
            for statement in statements {
                coordinator.processStatement(statement)
            }
        }
    }
    
    func testAudioProcessingPerformance() throws {
        let audioData = Data(repeating: 0, count: 44100) // 1 second of audio at 44.1kHz
        
        measure {
            for _ in 0..<100 {
                coordinator.audioService.processAudioBuffer(audioData)
            }
        }
    }
    
    func testSpeakerIdentificationPerformance() throws {
        // Create test speakers
        for i in 0..<50 {
            let speaker = Speaker(
                id: UUID(),
                name: "Speaker \(i)",
                voiceProfile: Data(repeating: UInt8(i), count: 1000)
            )
            coordinator.speakerService.addSpeaker(speaker)
        }
        
        let testVoiceData = Data(repeating: 25, count: 1000)
        
        measure {
            _ = coordinator.speakerService.identifySpeaker(from: testVoiceData)
        }
    }
    
    func testMemoryUsage() throws {
        // Test memory usage with large datasets
        let initialMemory = getMemoryUsage()
        
        // Create large number of fact check results
        for i in 0..<1000 {
            let result = FactCheckResult(
                id: UUID(),
                statement: "Test statement \(i)",
                veracity: .true,
                confidence: 0.8,
                sources: [],
                timestamp: Date(),
                processingTime: 1.0,
                claimType: .factual
            )
            coordinator.addResult(result)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (less than 50MB for 1000 results)
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024)
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}
