//
//  NetworkServiceTestIsolationTests.swift
//  SphirTests
//

import Testing
import Foundation
@testable import Sphir

private final class IsolationStubProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://sphir-api.onrender.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let body = Data("{}".utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct NetworkServiceTestIsolationTests {

    @Test func isRunningTestsIsTrue() {
        #expect(NetworkService.isRunningTests)
    }

    @Test func sharedRefusesRequestsInTests() async {
        let clock = ContinuousClock()
        var caughtExpectedError = false
        let elapsed = await clock.measure {
            do {
                _ = try await NetworkService.shared.preview(url: "https://example.com")
                Issue.record("Expected NetworkService.shared.preview to throw NetworkError.transport")
            } catch NetworkError.transport(let underlying) {
                if let urlError = underlying as? URLError, urlError.code == .notConnectedToInternet {
                    caughtExpectedError = true
                } else {
                    Issue.record("Expected URLError(.notConnectedToInternet), got \(underlying)")
                }
            } catch {
                Issue.record("Expected NetworkError.transport, got \(error)")
            }
        }
        #expect(caughtExpectedError)
        #expect(elapsed < .seconds(1))
    }

    @Test func stubbedInstancePerformsRequest() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [IsolationStubProtocol.self]
        let stubbedSession = URLSession(configuration: config)
        let service = NetworkService(session: stubbedSession, allowsNetwork: true)

        let _: EmptyResponse = try await service.request("/api/v1/test", method: .get, authorized: false)
    }
}
