import SwiftUI

@main
struct MyApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Palette.ink)
        }
    }
}

struct RootView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ConversationListView(path: $path)
                .navigationDestination(for: UUID.self) { id in
                    ChatView(conversationID: id)
                }
        }
        .tint(Palette.ink)
    }
}
