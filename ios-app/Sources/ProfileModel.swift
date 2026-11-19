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
    @Published var apiConfig: APIConfig {
        didSet {
            if let data = try? JSONEncoder().encode(apiConfig) {
                defaults.set(data, forKey: "profile.api")
            }
        }
    }

    @Published private(set) var avatar: UIImage?
    @Published private(set) var customBackground: UIImage?

    private let defaults = UserDefaults.standard
    private var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var avatarURL: URL { docs.appendingPathComponent("avatar.jpg") }
    private var backgroundURL: URL { docs.appendingPathComponent("background.jpg") }

    init() {
        let storedName = defaults.string(forKey: "profile.name") ?? ""
        name = storedName.isEmpty ? "小树" : String(storedName.prefix(12))
        themeID = defaults.string(forKey: "profile.theme") ?? "clover"
        if let data = defaults.data(forKey: "profile.api"),
           let config = try? JSONDecoder().decode(APIConfig.self, from: data) {
            apiConfig = config
        } else {
            apiConfig = APIConfig()
        }
        avatar = UIImage(contentsOfFile: avatarURL.path) ?? UIImage(named: "Avatar")
        if themeID == "custom" {
            customBackground = UIImage(contentsOfFile: backgroundURL.path)
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

    func resetProfile() {
        name = "小树"
        avatar = UIImage(named: "Avatar")
        try? FileManager.default.removeItem(at: avatarURL)
    }
}
