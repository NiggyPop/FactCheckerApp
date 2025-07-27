//
//  APIClient.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import Combine

class APIClient: ObservableObject {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String
    
    @Published var isOnline = true
    private var reachability: NetworkReachability?
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.API.timeout
        config.timeoutIntervalForResource = AppConfig.API.timeout * 2
        
        self.session = URLSession(configuration: config)
        self.baseURL = URL(string: AppConfig.API.baseURL)!
        self.apiKey = AppConfig.API.apiKey
        
        setupNetworkMonitoring()
    }
    
    // MARK: - Generic Request Method
    
    func request<T: Codable>(
        endpoint: APIEndpoint,
        responseType: T.Type
    ) -> AnyPublisher<T, APIError> {
        
        guard isOnline else {
            return Fail(error: APIError.noInternetConnection)
                .eraseToAnyPublisher()
        }
        
        guard let request = buildRequest(for: endpoint) else {
            return Fail(error: APIError.invalidRequest)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw APIError.serverError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError
                } else if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.networkError(error)
                }
            }
            .retry(AppConfig.API.maxRetries)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Specific API Methods
    
    func checkFact(_ statement: String) -> AnyPublisher<FactCheckResponse, APIError> {
        let endpoint = APIEndpoint.factCheck(statement: statement)
        return request(endpoint: endpoint, responseType: FactCheckResponse.self)
    }
    
    func getReliableSources() -> AnyPublisher<[ReliableSource], APIError> {
        let endpoint = APIEndpoint.reliableSources
        return request(endpoint: endpoint, responseType: [ReliableSource].self)
    }
    
    func reportFeedback(_ feedback: UserFeedback) -> AnyPublisher<FeedbackResponse, APIError> {
        let endpoint = APIEndpoint.feedback(feedback)
        return request(endpoint: endpoint, responseType: FeedbackResponse.self)
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(for endpoint: APIEndpoint) -> URLRequest? {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        if let body = endpoint.body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                return nil
            }
        }
        
        return request
    }
    
    private func setupNetworkMonitoring() {
        reachability = NetworkReachability()
        reachability?.startMonitoring { [weak self] status in
            DispatchQueue.main.async {
                self?.isOnline = status != .notReachable
            }
        }
    }
}

// MARK: - API Models

enum APIEndpoint {
    case factCheck(statement: String)
    case reliableSources
    case feedback(UserFeedback)
    
    var path: String {
        switch self {
        case .factCheck:
            return "fact-check"
        case .reliableSources:
            return "sources"
        case .feedback:
            return "feedback"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .factCheck, .feedback:
            return .POST
        case .reliableSources:
            return .GET
        }
    }
    
    var body: [String: Any]? {
        switch self {
        case .factCheck(let statement):
            return ["statement": statement]
        case .feedback(let feedback):
            return [
                "result_id": feedback.resultId.uuidString,
                "rating": feedback.rating,
                "comment": feedback.comment
            ]
        case .reliableSources:
            return nil
        }
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

enum APIError: Error, LocalizedError {
    case invalidRequest
    case invalidResponse
    case noInternetConnection
    case serverError(Int)
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return L("error_invalid_request")
        case .invalidResponse:
            return L("error_invalid_response")
        case .noInternetConnection:
            return L("error_no_internet")
        case .serverError(let code):
            return L("error_server") + " (\(code))"
        case .decodingError:
            return L("error_decoding")
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

struct FactCheckResponse: Codable {
    let id: String
    let statement: String
    let veracity: String
    let confidence: Double
    let sources: [SourceResponse]
    let processingTime: Double
    let claimType: String
}

struct SourceResponse: Codable {
    let url: String
    let title: String
    let credibilityScore: Double
    let summary: String
}

struct ReliableSource: Codable {
    let domain: String
    let name: String
    let credibilityScore: Double
    let category: String
}

struct UserFeedback: Codable {
    let resultId: UUID
    let rating: Int
    let comment: String
}

struct FeedbackResponse: Codable {
    let success: Bool
    let message: String
}
