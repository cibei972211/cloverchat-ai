import SwiftUI

@main
struct CloverChatApp: App {
    @StateObject private var profile: ProfileModel
    @StateObject private var chat: ChatModel

    init() {
        let profile = ProfileModel()
        _profile = StateObject(wrappedValue: profile)
        _chat = StateObject(wrappedValue: ChatModel(profile: profile))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profile)
                .environmentObject(chat)
                .preferredColorScheme(.dark)
        }
    }
}
