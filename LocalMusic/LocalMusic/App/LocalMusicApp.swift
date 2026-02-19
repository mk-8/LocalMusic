import SwiftUI

@main
struct LocalMusicApp: App {
    let coreDataStack = CoreDataStack.shared

    init() {
        // Wire up lock-screen / headphone remote commands at launch.
        RemoteCommandService.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.context)
                .environmentObject(AudioService.shared)
        }
    }
}
