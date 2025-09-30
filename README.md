# Gate/AI iOS SDK Sample App

This sample iOS application demonstrates how to integrate and use the Gate/AI iOS SDK for secure API gateway authentication. The app showcases the key features of the SDK including authentication, proxy requests, and cache management.

## Features

- **Authentication Testing**: Test the Gate/AI authentication flow
- **Proxy Requests**: Demonstrate making authenticated requests through the Gate/AI proxy
- **Cache Management**: Clear cached authentication state
- **Error Handling**: Show proper error handling and user feedback
- **Configuration Display**: View current SDK configuration settings

## Prerequisites

- Xcode 16.0 or newer with Swift 6 toolchain
- iOS 15+ deployment target
- Apple Developer account with App Attest entitlement enabled
- Real iOS device for production testing (App Attest requires physical device)
- Access to your Gate/AI tenant domain

## Setup Instructions

### 1. Configure the Project

1. Open `GateAISample.xcodeproj` in Xcode
2. Update the following in `ContentView.swift`:
   - Replace `"https://demo.us01.gate-ai.net"` with your actual Gate/AI tenant URL
   - Replace `"YOUR_TEAM_ID"` with your Apple Team ID
   - For simulator testing, replace `"your-dev-token-here"` with a valid development token

### 2. Add the Gate/AI iOS SDK

**IMPORTANT**: The project is currently set up without the package dependency to avoid build errors. You need to add it manually:

#### Option A: Local Package (Development)
1. In Xcode, choose **File ▸ Add Package Dependencies...**
2. Click **Add Local...** and select the `../iOS-Swift` directory
3. Add the `iOS_Swift` library to your target
4. Uncomment the import in `ContentView.swift`: `import iOS_Swift`
5. Uncomment the configuration code in the `setupConfiguration()` method
6. Replace the placeholder types (`Any?`) with actual types (`GateAIConfiguration?`, `GateAIClient?`)
7. Re-enable the buttons by changing `.disabled(true)` back to `.disabled(!viewModel.isConfigured || viewModel.isLoading)`

#### Option B: Remote Package (When Published)
1. In Xcode, choose **File ▸ Add Package Dependencies...**
2. Enter the Git URL of the published package
3. Select the appropriate version and add to your target
4. Follow steps 4-7 from Option A above

### 3. Configure Code Signing

1. Select the `GateAISample` target in Xcode
2. Go to **Signing & Capabilities**
3. Set your development team
4. Update the bundle identifier to match your Apple Developer account
5. Ensure **App Attest** capability is enabled

### 4. Update Configuration

Edit the configuration in `ContentView.swift`:

```swift
private func setupConfiguration() {
    guard let baseURL = URL(string: "https://yourteam.us01.gate-ai.net") else {
        lastError = "Invalid base URL"
        return
    }

    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.yourcompany.GateAISample"

    #if targetEnvironment(simulator)
    let devToken = "your-actual-dev-token-here"
    #else
    let devToken: String? = nil
    #endif

    configuration = GateAIConfiguration(
        baseURL: baseURL,
        bundleIdentifier: bundleIdentifier,
        teamIdentifier: "YOUR_ACTUAL_TEAM_ID",
        developmentToken: devToken
    )
}
```

## Usage

### Testing Authentication

1. Tap **Test Authentication** to verify the SDK can authenticate with Gate/AI
2. This will test the complete flow:
   - Device key generation/loading
   - App Attest challenge and assertion
   - Token exchange with DPoP proof
   - Access token retrieval

### Testing Proxy Requests

1. Tap **Test Proxy Request** to make an authenticated API call
2. This demonstrates:
   - Automatic authorization header generation
   - DPoP proof creation for the specific request
   - Handling of nonce challenges (401 responses)
   - Successful proxy request to OpenAI API

### Clearing Cache

1. Tap **Clear Cache** to reset the authentication state
2. This will clear in-memory tokens (device keys remain in Secure Enclave)

## Code Structure

- `GateAISampleApp.swift`: Main app entry point
- `ContentView.swift`: Main UI and sample logic
- `GateAISampleViewModel.swift`: Business logic and SDK interaction (embedded in ContentView.swift)

## Key SDK APIs Demonstrated

```swift
// Initialize the client
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
```

## Error Handling

The app demonstrates proper error handling for common scenarios:

- Configuration errors
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

1. **"Client not configured"**: Check your base URL, team ID, and bundle identifier
2. **Authentication failures**: Verify your tenant configuration and App Attest setup
3. **Build errors**: Ensure iOS-Swift package is properly added and Xcode version is 16.0+
4. **App Attest errors**: Verify entitlements and test on physical device

### Debugging Tips

- Enable detailed logging in your Gate/AI tenant console
- Check the Response section in the app for detailed error messages
- Verify network connectivity and tenant URL accessibility
- Ensure your Apple Team ID is registered with your Gate/AI tenant

## Next Steps

This sample app provides a foundation for integrating Gate/AI into your own applications. Key considerations for production:

1. Secure storage of configuration values
2. Proper error handling and user messaging
3. Background refresh of access tokens
4. Logging and monitoring integration
5. Testing across different network conditions

For more detailed integration information, see the [Integration Guide](../iOS-Swift/INTEGRATION.md).