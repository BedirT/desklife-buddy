import Foundation
import SwiftData

enum AppModelContainer {
    static let schema = Schema([
        StoredItem.self,
        StoredOpportunityEvent.self,
        StoredEstimatedActiveUseRun.self,
        StoredProtocolState.self,
        StoredAppPreferences.self,
        StoredOnboardingCompletion.self,
    ])

    static func make(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let configuration = if let url {
            ModelConfiguration("App", schema: schema, url: url)
        } else {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
