import CryptomatorCommonCore
import Dependencies

nonisolated protocol CacheControlling: Sendable {
	/**
	 Returns the current total local cache size in bytes reported by the File
	 Provider cache service.

	 The reported size reflects only entries counted by that service.
	 */
	func getLocalCacheSizeInBytes() async throws -> Int

	/**
	 Clears the local cache through the File Provider cache service.

	 Entries that the underlying service cannot currently evict may remain cached.
	 */
	func clearCache() async throws
}

nonisolated struct XPCCacheController: CacheControlling {
	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	func getLocalCacheSizeInBytes() async throws -> Int {
		let xpc: XPC<CryptomatorCommonCore.CacheManaging> = try await fileProviderConnector.getXPC(serviceName: .cacheManaging, domain: nil)
		defer {
			fileProviderConnector.invalidateXPC(xpc)
		}
		return try await xpc.proxy.getLocalCacheSizeInBytes()?.intValue ?? 0
	}

	func clearCache() async throws {
		let xpc: XPC<CryptomatorCommonCore.CacheManaging> = try await fileProviderConnector.getXPC(serviceName: .cacheManaging, domain: nil)
		defer {
			fileProviderConnector.invalidateXPC(xpc)
		}
		try await xpc.proxy.clearCache()
	}
}

private nonisolated enum CacheControllerKey: DependencyKey {
	static var liveValue: any CacheControlling {
		XPCCacheController()
	}

	#if DEBUG
	static let testValue: any CacheControlling = UnimplementedCacheController()
	#endif
}

nonisolated extension DependencyValues {
	var cacheController: any CacheControlling {
		get { self[CacheControllerKey.self] }
		set { self[CacheControllerKey.self] = newValue }
	}
}

#if DEBUG
private nonisolated struct UnimplementedCacheController: CacheControlling {
	func getLocalCacheSizeInBytes() async throws -> Int {
		reportIssue("\(Self.self).getLocalCacheSizeInBytes() not implemented")
		throw UnimplementedError()
	}

	func clearCache() async throws {
		reportIssue("\(Self.self).clearCache() not implemented")
		throw UnimplementedError()
	}

	private struct UnimplementedError: Error {}
}
#endif
