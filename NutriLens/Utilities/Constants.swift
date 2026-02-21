import Foundation

enum AppConstants {
    /// Cloudflare Worker proxy URL — update after deploying with `npx wrangler deploy`
    static let apiBaseURL = "https://nutrilens-api.nutrilens.workers.dev"

    /// App token for authenticating with the Worker proxy
    /// Set this to match the APP_TOKEN secret on the Worker
    static let appToken = "nutrilens-2026-secret-xyz"
}
