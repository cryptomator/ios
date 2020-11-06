# IntegrationTest

  

This Integration Test tests the individual CloudProvider implementations against the Live API of the respective Cloud Provider.

  

## Template

```swift
import CryptomatorCloudAccess
import XCTest

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
	//This is the folder in which all the files and folders required by the integration test are created and in which the individual tests are executed. This can also be the root folder.
	static let folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName = CloudPath("/yourPath/")

	override class var folderWhereTheIntegrationTestFolderIsCreated: CloudPath {
		return folderWhereTheIntegrationTestFolderIsCreatedAtCloudProviderName
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
		//Invalidate or deauthenticate the credential or client used by the CloudProvider.
	}

}

```




  

  

## Important Notes

  

The respective CloudProvider is tested here very generally for the specifications of the CloudProvider protocol. Special characteristics of the cloud provider must be tested separately.

  

### Google Drive

  

- Correct use of the cache for `resolvePath`

  

### Dropbox

- `batchUpload` works (file size >= 150mb)
