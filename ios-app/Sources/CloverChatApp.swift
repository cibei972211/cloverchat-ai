import SwiftUI

@main
struct CloverChatApp: App {
    @StateObject private var profile: ProfileModel
    @StateObject private var chat: ChatModel

    init() {
        let profile = ProfileModel()
        _profile = StateObject(wrappedValue: profile)
        _chat = StateObject(wrappedValue: ChatModel(profile: profile))
        // 预热触感引擎：第一次点按钮就不会有握手延迟
        Haptics.prepare()
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
