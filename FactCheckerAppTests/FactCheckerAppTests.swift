import XCTest
@testable import FactCheckerApp
import Combine

class FactCheckerAppTests: XCTestCase {
    var coordinator: FactCheckCoordinator!
    var mockAudioService: MockAudioService!
    var mockFactCheckService: MockFactCheckService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        mockAudioService = MockAudioService()
        mockFactCheckService = MockFactCheckService()
        coordinator = FactCheckCoordinator()
        coordinator.audioService = mockAudioService
        coordinator.factCheckService = mockFactCheckService
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        coordinator = nil
        mockAudioService = nil
        mockFactCheckService = nil
        cancellables = nil
    }
    
    func testFactCheckingFlow() throws {
        // Given
        let expectation = XCTestExpectation(description: "Fact check completed")
        let testStatement = "The Earth is flat"
        
        // When
        coordinator.$currentResult
            .dropFirst()
            .sink { result in
                if result != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        coordinator.processStatement(testStatement)
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertNotNil(coordinator.currentResult)
        XCTAssertEqual(coordinator.currentResult?.statement, testStatement)
    }
    
    func testAudioProcessing() throws {
        // Given
        let expectation = XCTestExpectation(description: "Audio processed")
        let testAudioData = Data(repeating: 0, count: 1024)
        
        // When
        mockAudioService.simulateAudioInput(testAudioData)
        
        coordinator.$isListening
            .dropFirst()
            .sink { isListening in
                if isListening {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        coordinator.startListening()
        
        // Then
        wait(for: [expectation], timeout: 3.0)
        XCTAssertTrue(coordinator.isListening)
    }
    
    func testSpeakerIdentification() throws {
        // Given
        let testSpeaker = Speaker(id: UUID(), name: "Test Speaker", voiceProfile: Data())
        let expectation = XCTestExpectation(description: "Speaker identified")
        
        // When
        coordinator.speakerService.addSpeaker(testSpeaker)
        
        coordinator.$currentSpeaker
            .dropFirst()
            .sink { speaker in
                if speaker != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        coordinator.speakerService.identifySpeaker(from: Data())
        
        // Then
        wait(for: [expectation], timeout: 3.0)
        XCTAssertNotNil(coordinator.currentSpeaker)
    }
    
    func testConfidenceThreshold() throws {
        // Given
        let lowConfidenceResult = FactCheckResult(
            id: UUID(),
            statement: "Test statement",
            veracity: .false,
            confidence: 0.3,
            sources: [],
            timestamp: Date(),
            processingTime: 1.0,
            claimType: .factual
        )
        
        // When
        coordinator.settingsManager.confidenceThreshold = 0.5
        let shouldShow = coordinator.shouldShowResult(lowConfidenceResult)
        
        // Then
        XCTAssertFalse(shouldShow)
    }
}

// MARK: - Mock Services

class MockAudioService: AudioServiceProtocol {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    
    var isRecordingPublisher: Published<Bool>.Publisher { $isRecording }
    var audioLevelPublisher: Published<Float>.Publisher { $audioLevel }
    
    func startRecording() {
        isRecording = true
    }
    
    func stopRecording() {
        isRecording = false
    }
    
    func simulateAudioInput(_ data: Data) {
        audioLevel = 0.5
        // Simulate transcription
        NotificationCenter.default.post(
            name: .audioTranscriptionReceived,
            object: "Simulated transcription"
        )
    }
}

class MockFactCheckService: FactCheckServiceProtocol {
    func checkFact(_ statement: String) -> AnyPublisher<FactCheckResult, Error> {
        let result = FactCheckResult(
            id: UUID(),
            statement: statement,
            veracity: .false,
            confidence: 0.9,
            sources: [
                FactCheckSource(
                    url: "https://example.com",
                    title: "Test Source",
                    credibilityScore: 0.8,
                    summary: "Test summary"
                )
            ],
            timestamp: Date(),
            processingTime: 1.0,
            claimType: .factual
        )
        
        return Just(result)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(100), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

extension Notification.Name {
    static let audioTranscriptionReceived = Notification.Name("audioTranscriptionReceived")
}
