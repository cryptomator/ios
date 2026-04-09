import AppIntents
import Dependencies

struct ClearCacheAppIntent: AppIntent {
	static let title: LocalizedStringResource = "Clear Cache"
	static let description = IntentDescription("Clears Cryptomator's local file cache.")
	static let openAppWhenRun = false
	@Dependencies.Dependency(\.cacheController) private var cacheController

	func perform() async throws -> some IntentResult & ProvidesDialog {
		try await cacheController.clearCache().getValue()
		return .result(dialog: "Cache cleared.")
	}
}

struct CryptomatorAppShortcutsProvider: AppShortcutsProvider {
	static var appShortcuts: [AppShortcut] {
		AppShortcut(
			intent: ClearCacheAppIntent(),
			phrases: [
				"Clear cache in \(.applicationName)",
				"Clear \(.applicationName) cache"
			],
			shortTitle: "Clear Cache",
			systemImageName: "trash"
		)
	}
}
