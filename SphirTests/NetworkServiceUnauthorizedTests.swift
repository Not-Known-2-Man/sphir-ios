//
//  NetworkServiceUnauthorizedTests.swift
//  SphirTests
//

import Testing
import Foundation
@testable import Sphir

private final class UnauthorizedStubProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://sphir-api.onrender.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let body = Data(#"{"error":"Invalid credentials"}"#.utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class NotificationSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var observer: NSObjectProtocol?
    private let center: NotificationCenter

    var wasPosted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return count > 0
    }

    init(name: Notification.Name, center: NotificationCenter) {
        self.center = center
        observer = center.addObserver(
            forName: name,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.count += 1
            self.lock.unlock()
        }
    }

    func stop() {
        if let observer {
            center.removeObserver(observer)
            self.observer = nil
        }
    }

    deinit {
        stop()
    }
}

@Suite(.serialized)
struct NetworkServiceUnauthorizedTests {
    /// Private center: other suites running in parallel never see these posts.
    private let center = NotificationCenter()

    private func makeService() -> NetworkService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UnauthorizedStubProtocol.self]
        return NetworkService(session: URLSession(configuration: config), notificationCenter: center)
    }

    @Test func unauthorizedRequestWithoutAuthThrowsInvalidCredentialsAndDoesNotPostNotification() async {
        let service = makeService()
        let spy = NotificationSpy(name: .sphirUnauthorized, center: center)
        defer { spy.stop() }

        do {
            let _: EmptyResponse = try await service.request("/api/v1/auth/sign_in", method: .post, authorized: false)
            Issue.record("Expected request to throw")
        } catch {
            #expect(error.localizedDescription == "Incorrect email or password.")
        }

        #expect(!spy.wasPosted)
    }

    @Test func unauthorizedRequestWithAuthThrowsUnauthorizedAndPostsNotification() async {
        let service = makeService()
        let spy = NotificationSpy(name: .sphirUnauthorized, center: center)
        defer { spy.stop() }

        do {
            let _: EmptyResponse = try await service.request("/api/v1/cards", method: .get, authorized: true)
            Issue.record("Expected request to throw")
        } catch {
            #expect(error.localizedDescription == "Your session expired. Please sign in again.")
        }

        #expect(spy.wasPosted)
    }
}
