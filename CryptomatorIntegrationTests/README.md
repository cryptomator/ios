# IntegrationTest

  

This Integration Test tests the individual CloudProvider implementations against the Live API of the respective Cloud Provider.

  

## Template

```swift

class CloudProviderNameCloudProviderIntegrationTests: CryptomatorIntegrationTestInterface {

	static var setUpErrorForCloudProviderName: Error?

	override class var classSetUpError: Error? {
		get {
			return setUpErrorForCloudProviderName
		}
		set {
			setUpErrorForCloudProviderName = newValue
		}
	}
	
	static let setUpProviderForCloudProviderName = CloudProviderNameCloudProvider()
	
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
		super.provider = CloudProviderNameCloudProvider()
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: CloudProviderNameCloudProviderIntegrationTests.self)
	}
}

```

## Authentication

If the cloud provider requires authentication, subclass `IntegrationTestWithAuthentication` instead of `CryptomatorIntegrationTestInterface`. 
This extends the IntegrationTest by tests for unauthorized CloudProvider actions.

The template from above can still be used. Additionally, the following function must be overridden:
```swift

class CloudProviderNameCloudProviderIntegrationTests: IntegrationTestWithAuthentication {

	override func deauthenticate() -> Promise<Void>{
		//Here the authentication object or client used by the cloud provider should be unauthenticated. 
		//If the cloud provider does not support true unauthentication, the credentials should be invalidated.
	}

}

```




  

  

## Important Notes

  

The respective CloudProvider is tested here very generally for the specifications of the CloudProvider protocol. Special characteristics of the cloud provider must be tested separately.

  

### Google Drive

  

- Correct use of the cache for `resolvePath`

  

### Dropbox

- `batchUpload` works (file size >= 150mb)
