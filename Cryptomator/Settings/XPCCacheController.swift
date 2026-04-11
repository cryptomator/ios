import CryptomatorCommonCore
import Dependencies
import Promises

protocol CacheControlling {
	/**
	 Returns the current total local cache size in bytes reported by the File
	 Provider cache service.

	 The reported size reflects only entries counted by that service.
	 */
	func getLocalCacheSizeInBytes() -> Promise<Int>

	/**
	 Clears the local cache through the File Provider cache service.

	 Entries that the underlying service cannot currently evict may remain cached.
	 */
	func clearCache() -> Promise<Void>
}

struct XPCCacheController: CacheControlling {
	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	func getLocalCacheSizeInBytes() -> Promise<Int> {
		let getXPCPromise: Promise<XPC<CryptomatorCommonCore.CacheManaging>> = fileProviderConnector.getXPC(serviceName: .cacheManaging, domain: nil)
		return getXPCPromise.then { xpc in
			xpc.proxy.getLocalCacheSizeInBytes()
		}.then {
			$0?.intValue ?? 0
		}.always {
			self.fileProviderConnector.invalidateXPC(getXPCPromise)
		}
	}

	func clearCache() -> Promise<Void> {
		let getXPCPromise: Promise<XPC<CryptomatorCommonCore.CacheManaging>> = fileProviderConnector.getXPC(serviceName: .cacheManaging, domain: nil)
		return getXPCPromise.then { xpc in
			xpc.proxy.clearCache()
		}.always {
			self.fileProviderConnector.invalidateXPC(getXPCPromise)
		}
	}
}

private enum CacheControllerKey: DependencyKey {
	static let testValue: any CacheControlling = XPCCacheController()
	static let liveValue: any CacheControlling = XPCCacheController()
}

extension DependencyValues {
	var cacheController: any CacheControlling {
		get { self[CacheControllerKey.self] }
		set { self[CacheControllerKey.self] = newValue }
	}
}
