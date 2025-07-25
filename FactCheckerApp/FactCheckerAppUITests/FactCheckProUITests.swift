//
//  FactCheckerAppUITests.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import XCTest

class FactCheckerAppUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testOnboardingFlow() throws {
        // Skip if not first launch
        if !app.staticTexts["Real-time Fact Checking"].exists {
            return
        }
        
        // Test onboarding pages
        XCTAssertTrue(app.staticTexts["Real-time Fact Checking"].exists)
        
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Speaker Identification"].exists)
        
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Detailed Analytics"].exists)
        
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Privacy First"].exists)
        
        app.buttons["Get Started"].tap()
        
        // Test permissions screen
        XCTAssertTrue(app.staticTexts["Permissions Required"].exists)
        
        // Grant microphone permission
        app.buttons["Allow"].tap()
        
        // Continue to main app
        app.buttons["Continue"].tap()
        
        // Verify main interface is shown
        XCTAssertTrue(app.tabBars.buttons["Fact Check"].exists)
    }
    
    func testMainFactCheckInterface() throws {
        // Navigate to main fact check tab
        app.tabBars.buttons["Fact Check"].tap()
        
        // Verify main elements exist
        XCTAssertTrue(app.buttons["Start Listening"].exists)
        XCTAssertTrue(app.staticTexts["Ready to fact-check"].exists)
        
        // Test start listening
        app.buttons["Start Listening"].tap()
        XCTAssertTrue(app.buttons["Stop Listening"].exists)
        
        // Test stop listening
        app.buttons["Stop Listening"].tap()
        XCTAssertTrue(app.buttons["Start Listening"].exists)
    }
    
    func testHistoryView() throws {
        // Navigate to history tab
        app.tabBars.buttons["History"].tap()
        
        // Verify history interface
        XCTAssertTrue(app.navigationBars["History"].exists)
        
        // Test search functionality
        if app.searchFields.firstMatch.exists {
            app.searchFields.firstMatch.tap()
            app.searchFields.firstMatch.typeText("test")
            
            // Verify search is active
            XCTAssertTrue(app.searchFields.firstMatch.value as? String == "test")
        }
        
        // Test filter button
        if app.buttons["Filter"].exists {
            app.buttons["Filter"].tap()
            XCTAssertTrue(app.sheets.firstMatch.exists)
            
            // Close filter sheet
            app.buttons["Done"].tap()
        }
    }
    
    func testStatisticsView() throws {
        // Navigate to statistics tab
        app.tabBars.buttons["Statistics"].tap()
        
        // Verify statistics interface
        XCTAssertTrue(app.navigationBars["Statistics"].exists)
        
        // Test timeframe picker
        if app.buttons["This Week"].exists {
            app.buttons["This Week"].tap()
            // Verify picker options are available
        }
        
        // Verify statistics cards exist
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Total Checks'")).firstMatch.exists)
    }
    
    func testSpeakerManagement() throws {
        // Navigate to speakers tab
        app.tabBars.buttons["Speakers"].tap()
        
        // Verify speaker management interface
        XCTAssertTrue(app.navigationBars["Speakers"].exists)
        
        // Test add speaker button
        if app.buttons["Add Speaker"].exists {
            app.buttons["Add Speaker"].tap()
            
            // Verify add speaker sheet
            XCTAssertTrue(app.sheets.firstMatch.exists)
            
            // Cancel adding speaker
            app.buttons["Cancel"].tap()
        }
    }
    
    func testSettingsView() throws {
        // Navigate to settings tab
        app.tabBars.buttons["Settings"].tap()
        
        // Verify settings interface
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        
        // Test theme setting
        if app.buttons["System"].exists {
            app.buttons["System"].tap()
            // Verify theme options are available
        }
        
        // Test toggle switches
        let hapticToggle = app.switches["Haptic Feedback"]
        if hapticToggle.exists {
            let initialValue = hapticToggle.value as? String
            hapticToggle.tap()
            let newValue = hapticToggle.value as? String
            XCTAssertNotEqual(initialValue, newValue)
        }
        
        // Test about section
        if app.buttons["About FactCheck Pro"].exists {
            app.buttons["About FactCheck Pro"].tap()
            XCTAssertTrue(app.navigationBars["About"].exists)
            app.buttons["Done"].tap()
        }
    }
    
    func testAccessibility() throws {
        // Test VoiceOver labels
        app.tabBars.buttons["Fact Check"].tap()
        
        let startButton = app.buttons["Start Listening"]
        XCTAssertNotNil(startButton.label)
        XCTAssertTrue(startButton.isHittable)
        
        // Test accessibility identifiers
        XCTAssertTrue(app.buttons.matching(identifier: "startListeningButton").firstMatch.exists)
    }
    
    func testLandscapeOrientation() throws {
        // Rotate to landscape
        XCUIDevice.shared.orientation = .landscapeLeft
        
        // Verify interface adapts
        app.tabBars.buttons["Fact Check"].tap()
        XCTAssertTrue(app.buttons["Start Listening"].exists)
        
        // Rotate back to portrait
        XCUIDevice.shared.orientation = .portrait
    }
}
