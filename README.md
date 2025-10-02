# Gate/AI iOS SDK Sample App

This sample iOS application demonstrates how to integrate and use the Gate/AI iOS SDK for secure API gateway authentication. The app showcases the key features of the SDK including authentication, proxy requests, and cache management.

Use this app as a reference or as troubleshooting if you encounter issues adding to your existing project.

## Prerequisites

- Xcode 16.0 or newer with Swift 6 toolchain
- iOS 15+ deployment target
- Apple Developer account with App Attest entitlement enabled
- Real iOS device for production testing (App Attest requires physical device)
- A Gate/AI account with a configured Gate.

## Setup Instructions

### 1. Configure the Project

1. Open `GateAISample.xcodeproj` in Xcode
2. Update the following in `ContentView.swift`:
   - Replace `"https://[gate-name].us01.gate-ai.net"` with your actual Gate/AI tenant URL
   - Replace `"YOUR_TEAM_ID"` with your Apple Team ID
   - For simulator testing, replace `"your-dev-token-here"` with a valid development token

### 2. Configure Code Signing

1. Select the `GateAISample` target in Xcode
2. Go to **Signing & Capabilities**
3. Set your development team
4. Update the bundle identifier to match your Apple Developer account
5. Ensure **App Attest** capability is enabled

## Usage

### Testing Authentication

This step (using `GateAIClient.currentAccessToken()`) is not necessary in normal use. It's here for illustrative purposes and to make it
quicker to test that your configuration and gate is setup correctly.

1. Tap **Test Authentication** to verify the SDK can authenticate with Gate/AI
2. This will test the complete flow:
   - Device key generation/loading
   - App Attest challenge and assertion
   - Token exchange with DPoP proof
   - Access token retrieval

### Testing Proxy Requests

This (`GateAIClient.performProxyRequest()`) is what you would follow in normal use.

1. Tap **Test Proxy Request** to make an authenticated API call
2. This demonstrates:
   - Automatic authorization header generation
   - DPoP proof creation for the specific request
   - Handling of nonce challenges (401 responses)
   - Successful proxy request to OpenAI API

### Clearing Cache

This is useful for testing purposes only. It should not be necessary in production use. If it is needed, open an issue on GitHub.

1. Tap **Clear Cache** to reset the authentication state
2. This will clear in-memory tokens (device keys remain in Secure Enclave)

## Code Structure

- `GateAISampleApp.swift`: Main app entry point
- `ContentView.swift`: Main UI and sample logic
- `GateAISampleViewModel.swift`: Business logic and SDK interaction (embedded in ContentView.swift)

## Key SDK APIs Demonstrated

```swift
// Initialize the configuration (throws if validation fails)
do {
    let configuration = try GateAIConfiguration(
        baseURLString: "https://yourteam.us01.gate-ai.net",
        teamIdentifier: "ABCDE12345",
        developmentToken: devToken,
        logLevel: .debug
    )

    let gateAIClient = GateAIClient(configuration: configuration)

    // Get access token
    let accessToken = try await gateAIClient.currentAccessToken()

    // Get authorization headers for a request
    let headers = try await gateAIClient.authorizationHeaders(
        for: "openai/chat/completions",
        method: .post
    )

    // Make a proxy request with automatic auth
    let (data, response) = try await gateAIClient.performProxyRequest(
        path: "openai/chat/completions",
        method: .post,
        body: requestBody,
        additionalHeaders: ["Content-Type": "application/json"]
    )

    // Clear cached state
    await gateAIClient.clearCachedState()
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## Error Handling

The app demonstrates proper error handling for common scenarios:

- Configuration errors (invalid URLs, malformed team IDs, empty bundle IDs)
- Authentication failures
- Network errors
- Gate/AI specific errors (device blocked, rate limited, etc.)
- DPoP nonce challenges

## Development vs Production

### Simulator Testing
- Uses development tokens when running in simulator
- App Attest is bypassed (not available in simulator)
- Secure Enclave keys are still used for DPoP

### Device Testing
- Uses full App Attest flow on physical devices
- Requires proper entitlements and team configuration
- No development token needed

## Troubleshooting

### Common Issues

1. **"Configuration error: teamIdentifier must be exactly 10 characters"**: Your Apple Team ID must be exactly 10 alphanumeric characters (e.g., "ABCDE12345"). Find it in your Apple Developer account or Xcode project settings.
2. **"Configuration error: Invalid base URL"**: Verify the base URL string is valid (e.g., "https://yourgate.us01.gate-ai.net")
3. **"Client not configured"**: Check your base URL, team ID, and bundle identifier
4. **Authentication failures**: Verify your tenant configuration and App Attest setup
5. **Build errors**: Ensure GateAI package is properly added and Xcode version is 16.0+
6. **App Attest errors**: Verify entitlements and test on physical device

### Debugging Tips

- Enable detailed logging in your Gate/AI tenant console
- Check the Response section in the app for detailed error messages
- Verify network connectivity and tenant URL accessibility
- Ensure your Apple Team ID is registered with your Gate/AI tenant
