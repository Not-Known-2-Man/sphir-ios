//
//  AuthAPIService.swift
//  Sphir
//
//  Auth endpoints. Tokens (token + uid) are persisted to the Keychain on
//  sign-in and cleared on sign-out. Protected requests use:
//    Authorization: Bearer <token>
//    uid: <uid>
//

import Foundation

// MARK: - DTOs

private struct SignInRequest: Encodable {
    let email: String
    let password: String
}

/// Flat sign-in / sign-up response: { token, uid, client, first_name, last_name }
private struct AuthResponse: Decodable {
    let token: String
    let uid: String
    let client: String?
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case token, uid, client
        case firstName = "first_name"
        case lastName  = "last_name"
    }
}

struct SignInResponse {
    let token: String
    let uid: String
    let firstName: String?
    let lastName: String?
}

private struct SignUpRequest: Encodable {
    let email: String
    let password: String
    let passwordConfirmation: String
    let accountType: String
    let domain: String

    enum CodingKeys: String, CodingKey {
        case email, password, domain
        case passwordConfirmation = "password_confirmation"
        case accountType = "account_type"
    }
}

// MARK: - Service

enum AuthAPIService {
    /// POST /api/v1/auth/sign_in — saves credentials to the Keychain.
    @discardableResult
    static func signIn(email: String, password: String) async throws -> SignInResponse {
        let auth: AuthResponse = try await NetworkService.shared.request(
            "/api/v1/auth/sign_in",
            method: .post,
            body: SignInRequest(email: email, password: password),
            authorized: false
        )
        KeychainService.saveCredentials(accessToken: auth.token, uid: auth.uid, client: auth.client)
        return SignInResponse(
            token: auth.token,
            uid: auth.uid,
            firstName: auth.firstName,
            lastName: auth.lastName
        )
    }

    /// POST /api/v1/auth — creates the account (does not sign in automatically).
    static func signUp(email: String, password: String) async throws {
        let _: AuthResponse = try await NetworkService.shared.request(
            "/api/v1/auth",
            method: .post,
            body: SignUpRequest(
                email: email,
                password: password,
                passwordConfirmation: password,
                accountType: "personal",
                domain: "sphir.io"
            ),
            authorized: false
        )
    }

    /// GET /api/v1/auth/guest — validates the guest endpoint; no credentials saved.
    static func continueAsGuest() async throws {
        let _: AuthResponse = try await NetworkService.shared.request(
            "/api/v1/auth/guest", method: .get, authorized: false
        )
    }

    /// DELETE /api/v1/auth/sign_out — best effort; always clears the Keychain.
    static func signOut() async {
        _ = try? await NetworkService.shared.request(
            "/api/v1/auth/sign_out",
            method: .delete
        ) as EmptyResponse
        KeychainService.clear()
    }
}
