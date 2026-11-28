import SwiftUI
import UIKit

struct APIConfig: Codable, Equatable {
    var baseUrl: String = ""
    var apiKey: String = ""
    var model: String = ""

    var isConfigured: Bool {
        !baseUrl.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

@MainActor
final class ProfileModel: ObservableObject {
    @Published var name: String {
        didSet { defaults.set(name, forKey: "profile.name") }
    }
    @Published var themeID: String {
        didSet { defaults.set(themeID, forKey: "profile.theme") }
    }
    /// AI 提示词（system prompt）。默认空白，完全由用户自己写。
    @Published var systemPrompt: String {
        didSet { defaults.set(systemPrompt, forKey: "profile.prompt") }
    }
    /// 发完消息后等多少秒才真的发给 AI（0 = 立刻）。给用户连发几条的余地。
    @Published var replyDelaySeconds: Double {
        didSet { defaults.set(replyDelaySeconds, forKey: "profile.replyDelay") }
    }
    @Published var apiConfig: APIConfig {
        didSet {
            if let data = try? JSONEncoder().encode(apiConfig) {
                defaults.set(data, forKey: "profile.api")
            }
        }
    }

    @Published private(set) var avatar: UIImage?
    @Published private(set) var customBackground: UIImage?
    /// App 内的应用名称（桌面上的名字由安装包决定，运行时改不了）
    @Published var appName: String {
        didSet { defaults.set(appName, forKey: "profile.appName") }
    }
    /// 用户自己裁剪的应用图标（存在本机 Documents，可导出、可打进下一版安装包）
    @Published private(set) var customIcon: UIImage?

    private let defaults = UserDefaults.standard
    private var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var avatarURL: URL { docs.appendingPathComponent("avatar.jpg") }
    private var backgroundURL: URL { docs.appendingPathComponent("background.jpg") }
    private var iconURL: URL { docs.appendingPathComponent("custom-icon.jpg") }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let storedName = defaults.string(forKey: "profile.name") ?? ""
        name = storedName.isEmpty ? "小树" : String(storedName.prefix(12))
        themeID = defaults.string(forKey: "profile.theme") ?? "clover"
        // 没存过就是空字符串 —— 不给任何默认人格提示词
        systemPrompt = defaults.string(forKey: "profile.prompt") ?? ""
        replyDelaySeconds = defaults.object(forKey: "profile.replyDelay") as? Double ?? 0
        appName = defaults.string(forKey: "profile.appName") ?? "小树"
        customIcon = UIImage(contentsOfFile: docs.appendingPathComponent("custom-icon.jpg").path)
        if let data = defaults.data(forKey: "profile.api"),
           let config = try? JSONDecoder().decode(APIConfig.self, from: data) {
            apiConfig = config
        } else {
            apiConfig = APIConfig()
        }
        avatar = UIImage(contentsOfFile: docs.appendingPathComponent("avatar.jpg").path) ?? UIImage(named: "Avatar")
        if themeID == "custom" {
            customBackground = UIImage(contentsOfFile: docs.appendingPathComponent("background.jpg").path)
        }
    }

    func saveAvatar(_ data: Data) {
        do {
            try data.write(to: avatarURL, options: .atomic)
            avatar = UIImage(data: data)
        } catch { /* keep old avatar */ }
    }

    func saveBackground(_ data: Data) {
        try? data.write(to: backgroundURL, options: .atomic)
        customBackground = UIImage(data: data)
        themeID = "custom"
    }

    /// 存图标：转成 JPEG 掉 alpha（App 图标不允许带透明通道）
    func saveIcon(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.94),
              (try? data.write(to: iconURL, options: .atomic)) != nil else { return }
        customIcon = UIImage(data: data)
    }

    func resetIcon() {
        try? FileManager.default.removeItem(at: iconURL)
        customIcon = nil
    }

    func resetProfile() {
        name = "小树"
        avatar = UIImage(named: "Avatar")
        try? FileManager.default.removeItem(at: avatarURL)
    }
}
