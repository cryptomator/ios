import Promises

public extension Promise {
	func getValue() async throws -> Value {
		try await withCheckedThrowingContinuation({ continuation in
			self.then(continuation.resume(returning:)).catch(continuation.resume(throwing:))
		})
	}
}
