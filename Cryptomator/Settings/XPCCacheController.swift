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
	static var liveValue: any CacheControlling {
		XPCCacheController()
	}

	#if DEBUG
	static var testValue: any CacheControlling = UnimplementedCacheController()
	#endif
}

extension DependencyValues {
	var cacheController: any CacheControlling {
		get { self[CacheControllerKey.self] }
		set { self[CacheControllerKey.self] = newValue }
	}
}

#if DEBUG
private struct UnimplementedCacheController: CacheControlling {
	func getLocalCacheSizeInBytes() -> Promise<Int> {
		unimplemented("\(Self.self).getLocalCacheSizeInBytes() not implemented", placeholder: Promise(UnimplementedError()))
	}

	func clearCache() -> Promise<Void> {
		unimplemented("\(Self.self).clearCache() not implemented", placeholder: Promise(UnimplementedError()))
	}

	private struct UnimplementedError: Error {}
}
#endif
