import SwiftUI
import GateAI

struct ContentView: View {
    @StateObject private var viewModel = GateAISampleViewModel()

    var body: some View {
        NavigationStack {
            List {
                configurationSection
                actionsSection
                usageSection
                responseSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Gate/AI Demo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        Section("Configuration") {
            configRow("Gate URL", value: viewModel.configuration?.baseURL.host ?? "Not set")
            configRow("Bundle ID", value: viewModel.configuration?.bundleIdentifier ?? "Not set")
            configRow("Environment", value: environmentLabel)
            HStack {
                Text("Dev token")
                Spacer()
                Label(viewModel.hasDevToken ? "Set" : "Not set",
                      systemImage: viewModel.hasDevToken ? "checkmark.circle.fill" : "minus.circle")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.hasDevToken ? Color.green : Color.secondary)
            }
        }
    }

    private func configRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var environmentLabel: String {
        #if targetEnvironment(simulator)
        "Simulator"
        #else
        "Device"
        #endif
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Group {
            Section {
                Button {
                    Task { await viewModel.testProxyRequest() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text("Send Proxy Request")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.isConfigured || viewModel.isLoading)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } header: {
                Text("Actions")
            } footer: {
                Text("Asks Gemini for a joke through your gate and shows the raw response.")
            }

            Section {
                Button {
                    Task { await viewModel.testAuthentication() }
                } label: {
                    Label("Test Authentication", systemImage: "person.badge.key")
                }
                .disabled(!viewModel.isConfigured || viewModel.isLoading)

                Button(role: .destructive) {
                    Task { await viewModel.clearCache() }
                } label: {
                    Label("Clear Cache & App Attest Key", systemImage: "trash")
                }
                .disabled(!viewModel.isConfigured || viewModel.isLoading)
            }
        }
    }

    // MARK: - Usage

    /// Remaining device quota from the last proxy response. Gates without device
    /// usage limits send no quota headers, so this stays hidden until a limit is set.
    @ViewBuilder
    private var usageSection: some View {
        if let quota = viewModel.quotaStatus {
            Section("Device usage") {
                if let limit = quota.requestsLimit, let remaining = quota.requestsRemaining {
                    quotaMeter(label: "Requests", used: limit - remaining, limit: limit, resetsAt: quota.requestsResetAt)
                }
                if let limit = quota.tokensLimit, let remaining = quota.tokensRemaining {
                    quotaMeter(label: "Tokens", used: limit - remaining, limit: limit, resetsAt: quota.tokensResetAt)
                }
            }
        }
    }

    private func quotaMeter(label: String, used: Int, limit: Int, resetsAt: Date?) -> some View {
        let fraction = Double(used) / Double(max(limit, 1))
        return VStack(alignment: .leading, spacing: 8) {
            Gauge(value: min(fraction, 1)) {
                Text(label)
            } currentValueLabel: {
                Text("\(used.formatted()) / \(limit.formatted())")
                    .monospacedDigit()
            }
            .gaugeStyle(.linearCapacity)
            .tint(fraction < 0.7 ? .green : fraction <= 0.9 ? .orange : .red)

            if let resetsAt {
                Text("Resets \(resetsAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Response

    private var responseSection: some View {
        Section("Response") {
            if let error = viewModel.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else if let response = viewModel.lastResponse {
                VStack(alignment: .leading, spacing: 8) {
                    Label(response.title, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                    if let detail = response.detail {
                        Text(detail)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 4)
            } else if viewModel.isLoading {
                Text("Waiting for the gate…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Run an action to see its result here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A successful outcome: a one-line summary plus optional raw detail (token, JSON body).
struct SampleResponse {
    let title: String
    var detail: String? = nil
}

@MainActor
class GateAISampleViewModel: ObservableObject {
    @Published var configuration: GateAIConfiguration?
    @Published var isLoading = false
    @Published var lastResponse: SampleResponse?
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
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "GateBaseURL") as? String,
              !baseURL.isEmpty,
              let teamIdentifier = Bundle.main.object(forInfoDictionaryKey: "GateTeamIdentifier") as? String,
              !teamIdentifier.isEmpty else {
            lastError = "Copy Local.xcconfig.example to Local.xcconfig and set your team ID and gate URL, then rebuild."
            return
        }

        do {
            // Using the convenience initializer with String URL and auto-detected bundle ID.
            // In the simulator the SDK reads a development token from the
            // GATE_AI_DEV_TOKEN environment variable (set it on the Run scheme);
            // on a device it uses App Attest and ignores the variable.
            configuration = try GateAIConfiguration(
                baseURLString: baseURL,
                teamIdentifier: teamIdentifier,
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
            lastResponse = SampleResponse(
                title: "Authenticated",
                detail: "Access token (first 20 chars): \(String(accessToken.prefix(20)))…"
            )
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
            lastResponse = SampleResponse(
                title: "Proxy request succeeded (HTTP \(response.statusCode))",
                detail: responseText
            )

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
                    lastError = "Rate limited (\(limit.code)): \(limit.used ?? 0)/\(limit.limit ?? 0) in the \(window) window. Resets \(reset)."
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
            lastResponse = SampleResponse(title: "Cache and App Attest key cleared")
        } catch {
            lastResponse = SampleResponse(
                title: "Cache cleared",
                detail: "App Attest key was not cleared: \(error.localizedDescription)"
            )
        }

        isLoading = false
    }
}

#Preview {
    ContentView()
}
