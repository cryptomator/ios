# IntegrationTest

This Integration Test tests the individual CloudProvider implementations against the Live API of the respective Cloud Provider. 

## Template
```swift
class CloudProviderNameCloudProviderIntegrationTests: IntegrationTestWithAuthentication {
	static var setUpErrorForCloudProviderName: Error?
	override class var classSetUpError: Error? {
		get {
			return setUpErrorForCloudProviderName
		}
		set {
			setUpErrorForCloudProviderName = newValue
		}
	}

	static let setUpAuthenticationForCloudProviderName = MockCloudProviderNameCloudAuthentication()
	static let setUpProviderForCloudProviderName = CloudProviderNameCloudProvider()
	override class var setUpAuthentication: MockCloudAuthentication {
		return setUpAuthenticationForCloudProviderName
	}

	override class var setUpProvider: CloudProvider {
		return setUpProviderForCloudProviderName
	}

	static let remoteRootURLForIntegrationTestAtCloudProviderName = URL(fileURLWithPath: "/yourPath/", isDirectory: true)
	override class var remoteRootURLForIntegrationTest: URL {
		return remoteRootURLForIntegrationTestAtCloudProviderName
	}
	
	//If you do not need to initialize anything special once or before the IntegrationTest setup, you can ignore this function.
	override class func setUp() {
		//It is very important to call super.setUp(), otherwise the IntegrationTest will not be built correctly.
		super.setUp()
	}

	override func setUpWithError() throws {
		//This call is very important, otherwise errors from the IntegrationTest once setup will not be considered correctly.
		try super.setUpWithError()
		let auth = MockCloudProviderNameCloudAuthentication()
		super.authentication = auth
		super.provider = CloudProviderNameCloudProvider()
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: CloudProviderNameCloudProviderIntegrationTests.self)
	}
}
```
## Authentication

Create a new `MockYourProviderNameCloudAuthentication`:
```swift
class MockYourProviderNameCloudAuthentication: YourProviderNameCloudAuthentication, MockCloudAuthentication {
	func  authenticate() -> Promise<Void>{
	//Authenticate here without a ViewController, for example with an OAuth token.
	//If your cloud provider does not require authentication, you can simply fulfill the Promise directly.
	}
}
```
### Providers that do not require authentication

If your cloud provider does not require authentication, subclass `CryptomatorIntegrationTestInterface` instead of `IntegrationTestWithAuthentication`.


## Important Notes

The respective CloudProvider is tested here very generally for the specifications of the CloudProvider protocol. Special characteristics of the cloud provider must be tested separately.

### Google Drive

 - Correct use of the cache for `resolvePath` 

### Dropbox
- `batchUpload` works (file size >= 150mb)
