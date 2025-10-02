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
        #if targetEnvironment(simulator)
        let devToken = "eyJr..."
        #else
        let devToken: String? = nil
        #endif

        do {
            // Using the convenience initializer with String URL and auto-detected bundle ID
            configuration = try GateAIConfiguration(
                baseURLString: "https://[gate-name].us01.gate-ai.net",
                teamIdentifier: "AB12C3D456",
                developmentToken: devToken,
                logLevel: .debug  // Enable debug logging to see all requests/responses
            )

            if let config = configuration {
                gateAIClient = GateAIClient(configuration: config)
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

        } catch {
            if let gateError = error as? GateAIError {
                lastError = "Proxy request failed: \(gateError)"
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
