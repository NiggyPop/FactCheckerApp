//
//  SpeakerServiceTests.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import XCTest
@testable import FactCheckPro

class SpeakerServiceTests: XCTestCase {
    var speakerService: SpeakerService!
    var mockContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "FactCheckModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        mockContext = container.viewContext
        speakerService = SpeakerService(context: mockContext)
    }
    
    override func tearDownWithError() throws {
        speakerService = nil
        mockContext = nil
    }
    
    func testAddSpeaker() throws {
        // Given
        let speaker = Speaker(
            id: UUID(),
            name: "Test Speaker",
            voiceProfile: Data(repeating: 1, count: 100)
        )
        
        // When
        speakerService.addSpeaker(speaker)
        
        // Then
        XCTAssertTrue(speakerService.speakers.contains { $0.id == speaker.id })
        XCTAssertEqual(speakerService.speakers.first?.name, "Test Speaker")
    }
    
    func testRemoveSpeaker() throws {
        // Given
        let speaker = Speaker(
            id: UUID(),
            name: "Test Speaker",
            voiceProfile: Data()
        )
        speakerService.addSpeaker(speaker)
        
        // When
        speakerService.removeSpeaker(speaker)
        
        // Then
        XCTAssertFalse(speakerService.speakers.contains { $0.id == speaker.id })
    }
    
    func testUpdateSpeaker() throws {
        // Given
        let speaker = Speaker(
            id: UUID(),
            name: "Original Name",
            voiceProfile: Data()
        )
        speakerService.addSpeaker(speaker)
        
        // When
        var updatedSpeaker = speaker
        updatedSpeaker.name = "Updated Name"
        speakerService.updateSpeaker(updatedSpeaker)
        
        // Then
        let foundSpeaker = speakerService.speakers.first { $0.id == speaker.id }
        XCTAssertEqual(foundSpeaker?.name, "Updated Name")
    }
    
    func testSpeakerIdentification() throws {
        // Given
        let speaker1 = Speaker(
            id: UUID(),
            name: "Speaker 1",
            voiceProfile: Data(repeating: 1, count: 100)
        )
        let speaker2 = Speaker(
            id: UUID(),
            name: "Speaker 2",
            voiceProfile: Data(repeating: 2, count: 100)
        )
        
        speakerService.addSpeaker(speaker1)
        speakerService.addSpeaker(speaker2)
        
        // When
        let testVoiceData = Data(repeating: 1, count: 100)
        let identifiedSpeaker = speakerService.identifySpeaker(from: testVoiceData)
        
        // Then
        XCTAssertNotNil(identifiedSpeaker)
        XCTAssertEqual(identifiedSpeaker?.id, speaker1.id)
    }
}
