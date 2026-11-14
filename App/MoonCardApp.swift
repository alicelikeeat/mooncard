import SwiftUI

@main struct MoonCardApp: App {
    @StateObject private var game = GameStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            GameScreen(game: game)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { phase in
                    game.suspended = phase != .active
                    game.movement = Point()
                    if phase != .active { game.save() }
                }
        }
    }
}
