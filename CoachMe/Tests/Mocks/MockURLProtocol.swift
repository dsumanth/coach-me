//
//  MockURLProtocol.swift
//  CoachMeTests
//
//  Created by Code Review on 2/6/26.
//

import Foundation

/// Mock URL protocol for testing network requests
/// Allows injecting mock responses for URLSession-based tests
final class MockURLProtocol: URLProtocol {

    /// Handler for processing requests and returning mock responses
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Convenience property for setting mock data
    static var mockData: Data?

    /// Convenience property for setting mock response
    static var mockResponse: HTTPURLResponse?

    /// Reset all mock state
    static func reset() {
        requestHandler = nil
        mockData = nil
        mockResponse = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        // Handle all requests
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        // Use request handler if provided
        if let handler = MockURLProtocol.requestHandler {
            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
            return
        }

        // Fall back to convenience properties
        guard let mockResponse = MockURLProtocol.mockResponse else {
            let error = NSError(domain: "MockURLProtocol", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No mock response configured"
            ])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        client?.urlProtocol(self, didReceive: mockResponse, cacheStoragePolicy: .notAllowed)

        if let mockData = MockURLProtocol.mockData {
            client?.urlProtocol(self, didLoad: mockData)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // No-op for mock
    }
}

// MARK: - Test Helpers

extension MockURLProtocol {
    /// Create a mock session configured to use this protocol
    static func createMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Configure a successful SSE response
    static func configureSSEResponse(events: [String], statusCode: Int = 200) {
        let sseData = events.joined(separator: "\n").data(using: .utf8) ?? Data()
        mockData = sseData
        mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.supabase.co/functions/v1/chat-stream")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/event-stream"]
        )
    }

    /// Configure an error response
    static func configureErrorResponse(statusCode: Int) {
        mockData = nil
        mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.supabase.co/functions/v1/chat-stream")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
    }
}
