//
//  FactCheckServiceTests.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import XCTest
import Combine
@testable import FactCheckerApp

class FactCheckServiceTests: XCTestCase {
    var factCheckService: FactCheckService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        factCheckService = FactCheckService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        factCheckService = nil
        cancellables = nil
    }
    
    func testFactCheckValidStatement() throws {
        // Given
        let expectation = XCTestExpectation(description: "Fact check completed")
        let statement = "Water boils at 100 degrees Celsius at sea level"
        
        // When
        factCheckService.checkFact(statement)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Unexpected error: \(error)")
                    }
                },
                receiveValue: { result in
                    // Then
                    XCTAssertEqual(result.statement, statement)
                    XCTAssertGreaterThan(result.confidence, 0.0)
                    XCTAssertLessThanOrEqual(result.confidence, 1.0)
                    XCTAssertFalse(result.sources.isEmpty)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFactCheckEmptyStatement() throws {
        // Given
        let expectation = XCTestExpectation(description: "Error received")
        let statement = ""
        
        // When
        factCheckService.checkFact(statement)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertTrue(error is FactCheckError)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive value for empty statement")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testClaimTypeClassification() throws {
        // Given
        let factualStatement = "The population of Tokyo is 14 million"
        let opinionStatement = "Tokyo is the best city in the world"
        
        // When
        let factualType = factCheckService.classifyClaimType(factualStatement)
        let opinionType = factCheckService.classifyClaimType(opinionStatement)
        
        // Then
        XCTAssertEqual(factualType, .factual)
        XCTAssertEqual(opinionType, .opinion)
    }
    
    func testSourceCredibilityScoring() throws {
        // Given
        let reliableSource = "https://www.reuters.com/article"
        let unreliableSource = "https://www.randomfakeblog.com/article"
        
        // When
        let reliableScore = factCheckService.calculateSourceCredibility(reliableSource)
        let unreliableScore = factCheckService.calculateSourceCredibility(unreliableSource)
        
        // Then
        XCTAssertGreaterThan(reliableScore, unreliableScore)
        XCTAssertGreaterThan(reliableScore, 0.7)
        XCTAssertLessThan(unreliableScore, 0.5)
    }
}
