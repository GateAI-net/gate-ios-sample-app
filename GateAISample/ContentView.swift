import SwiftUI
import GateAI

struct ContentView: View {
    @StateObject private var viewModel = GateAISampleViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection

                configurationSection

                actionsSection

                usageSection

                responseSection

                Spacer()
            }
            .padding()            
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("Gate/AI SDK Demo")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Demonstrates secure API gateway authentication")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var configurationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Base URL:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(viewModel.configuration?.baseURL.absoluteString ?? "Not set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Bundle ID:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(viewModel.configuration?.bundleIdentifier ?? "Not set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Environment:")
                        .fontWeight(.medium)
                    Spacer()
                    #if targetEnvironment(simulator)
                    Text("Simulator")
                        .font(.caption)
                        .foregroundColor(.orange)
                    #else
                    Text("Device")
                        .font(.caption)
                        .foregroundColor(.blue)
                    #endif
                }

                HStack {
                    Text("Dev Token Set:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(viewModel.hasDevToken ? "Yes" : "No")
                        .font(.caption)
                        .foregroundColor(viewModel.hasDevToken ? .green : .red)
                }

            }
        }
    }

    /// Remaining device quota from the last proxy response. Gates without device
    /// usage limits send no quota headers, so this stays hidden until a limit is set.
    @ViewBuilder
    private var usageSection: some View {
        if let quota = viewModel.quotaStatus {
            GroupBox("Device usage") {
                VStack(alignment: .leading, spacing: 10) {
                    if let limit = quota.requestsLimit, let remaining = quota.requestsRemaining {
                        quotaMeter(label: "Requests", used: limit - remaining, limit: limit, resetsAt: quota.requestsResetAt)
                    }
                    if let limit = quota.tokensLimit, let remaining = quota.tokensRemaining {
                        quotaMeter(label: "Tokens", used: limit - remaining, limit: limit, resetsAt: quota.tokensResetAt)
                    }
                }
            }
        }
    }

    private func quotaMeter(label: String, used: Int, limit: Int, resetsAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).fontWeight(.medium)
                Spacer()
                Text("\(used.formatted()) / \(limit.formatted())")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            ProgressView(value: Double(used), total: Double(max(limit, 1)))
            if let resetsAt {
                Text("Resets \(resetsAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await viewModel.testAuthentication()
                }
            }) {
                HStack {
                    Image(systemName: "person.badge.key")
                    Text("Test Authentication")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!viewModel.isConfigured || viewModel.isLoading)

            Button(action: {
                Task {
                    await viewModel.testProxyRequest()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Test Proxy Request")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!viewModel.isConfigured || viewModel.isLoading)

            Button(action: {
                Task {
                    await viewModel.clearCache()
                }
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear Cache")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!viewModel.isConfigured || viewModel.isLoading)
        }
    }

    private var responseSection: some View {
        GroupBox("Response") {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(.caption)
                        }
                    }

                    if let error = viewModel.lastError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    if let response = viewModel.lastResponse {
                        Text(response)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 100, maxHeight: 200)
        }
    }
}

@MainActor
class GateAISampleViewModel: ObservableObject {
    @Published var configuration: GateAIConfiguration?
    @Published var isLoading = false
    @Published var lastResponse: String?
    @Published var lastError: String?
    @Published var quotaStatus: GateAIQuotaStatus?

    private var gateAIClient: GateAIClient?

    var isConfigured: Bool {
        configuration != nil && gateAIClient != nil
    }

    var hasDevToken: Bool {
        configuration?.developmentToken != nil
    }

    init() {
        setupConfiguration()
    }

    private func setupConfiguration() {
        do {
            // Using the convenience initializer with String URL and auto-detected bundle ID.
            // In the simulator the SDK reads a development token from the
            // GATE_AI_DEV_TOKEN environment variable (set it on the Run scheme);
            // on a device it uses App Attest and ignores the variable.
            configuration = try GateAIConfiguration(
                baseURLString: "https://[gate-name].in.gate-ai.net",
                teamIdentifier: "YOUR-TEAM-ID",
                logLevel: .debug  // Enable debug logging to see all requests/responses
            )

            if let config = configuration {
                let client = GateAIClient(configuration: config)

                // Analytics (optional): break down usage in the Portal by user,
                // feature, and segment. Use an opaque ID — never an email or name.
                client.userIdentifier = "sample-user-1"
                client.appFeature = "joke"
                client.userStatus = "trial"

                // Usage limits: `userTier` is the exact, case-sensitive key for
                // per-tier limits configured on the gate; `quotaAnchorDay` (1–31)
                // lets a billing-cycle budget reset on this user's renewal day.
                client.userTier = "free"
                client.quotaAnchorDay = 15

                gateAIClient = client
            }
        } catch {
            lastError = "Configuration error: \(error.localizedDescription)"
        }
    }

    func testAuthentication() async {
        guard let client = gateAIClient else {
            lastError = "Client not configured"
            return
        }

        isLoading = true
        lastError = nil
        lastResponse = nil

        do {
            let accessToken = try await client.currentAccessToken()
            lastResponse = "✅ Authentication successful!\n\nAccess token received (showing first 20 chars): \(String(accessToken.prefix(20)))..."
        } catch {
            lastError = "Authentication failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func testProxyRequest() async {
        
        guard let client = gateAIClient else {
            lastError = "Client not configured"
            return
        }

        isLoading = true
        lastError = nil
        lastResponse = nil

        do {
            let requestBody = """
            {
                "contents": {
                    "parts": [
                        { "text": "Tell me a joke, please." }
                    ]
                }
            }
            """.data(using: .utf8)!

            let (data, response) = try await client.performProxyRequest(
                path: "/v1beta/models/gemini-2.5-flash:generateContent",
                method: .post,
                body: requestBody,
                additionalHeaders: ["Content-Type": "application/json"]
            )

            let responseText = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            lastResponse = "✅ Proxy request successful!\n\nStatus: \(response.statusCode)\n\nResponse:\n\(responseText)"

            // Remaining device quota rides along on every response once the gate
            // has usage limits configured; render it as a meter.
            quotaStatus = response.gateAIQuotaStatus

        } catch {
            if let gateError = error as? GateAIError {
                if let limit = gateError.rateLimitInfo {
                    // A structured 429: tell the user which budget closed and when it
                    // reopens — the natural place for an upgrade prompt.
                    let window = limit.window?.rawValue ?? "unknown"
                    let reset = limit.resetsAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "later"
                    lastError = "⏳ Rate limited (\(limit.code)): \(limit.used ?? 0)/\(limit.limit ?? 0) in the \(window) window. Resets \(reset)."
                } else {
                    lastError = "Proxy request failed: \(gateError)"
                }
            } else {
                lastError = "Proxy request failed: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    func clearCache() async {
        guard let client = gateAIClient else {
            lastError = "Client not configured"
            return
        }

        isLoading = true
        lastError = nil
        lastResponse = nil

        await client.clearCachedState()

        // Also clear App Attest key
        do {
            try client.clearAppAttestKey()
            lastResponse = "✅ Cache and App Attest key cleared successfully!"
        } catch {
            lastResponse = "✅ Cache cleared, but failed to clear App Attest key: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

#Preview {
    ContentView()
}
