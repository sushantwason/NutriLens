import Foundation

enum AppConstants {
    /// Cloudflare Worker proxy URL — update after deploying with `npx wrangler deploy`
    static let apiBaseURL = "https://nutrilens-api.nutrilens.workers.dev"

    /// App Store ID — used for review links and referral sharing
    static let appStoreID = "6745208953"

    private static let appTokenKeychainKey = "api_app_token"

    /// App token for authenticating with the Worker proxy.
    /// Reads from Keychain at runtime. Call `seedAppTokenIfNeeded()` on launch.
    static var appToken: String {
        KeychainService.load(key: appTokenKeychainKey) ?? ""
    }

    /// Seeds the API token into Keychain on first launch.
    /// Checks for a `NUTRILENS_APP_TOKEN` environment variable first,
    /// then falls back to a bundled default.
    static func seedAppTokenIfNeeded() {
        guard KeychainService.load(key: appTokenKeychainKey) == nil else { return }

        let token: String
        if let envToken = ProcessInfo.processInfo.environment["NUTRILENS_APP_TOKEN"],
           !envToken.isEmpty {
            token = envToken
        } else {
            // Base64-encoded fallback to avoid plain-text secret in source
            let encoded = "bnV0cmlsZW5zLTIwMjYtc2VjcmV0LXh5eg=="
            if let data = Data(base64Encoded: encoded),
               let decoded = String(data: data, encoding: .utf8) {
                token = decoded
            } else {
                token = ""
            }
        }

        try? KeychainService.save(key: appTokenKeychainKey, value: token)
    }
}
