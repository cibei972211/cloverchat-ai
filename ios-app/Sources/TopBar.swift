import SwiftUI

// MARK: - 顶部栏：返回胶囊 / 视频通话 / 头像 + 名字胶囊
//
// 布局说明：玻璃只画在元素自身 bounds 上（glassButton / glassPanel），
// 绝不用 GlassEffectContainer 包整屏 —— 那会导致玻璃形状错位画出屏幕。

struct TopBar: View {
    @EnvironmentObject private var profile: ProfileModel
    let onBack: () -> Void
    let onVideo: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top) {
                backButton
                Spacer()
                videoButton
            }
            VStack(spacing: 9) {
                avatarButton
                namePill
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 42)
        }
        .glassButton(cornerRadius: 21)
    }

    private var videoButton: some View {
        Button(action: onVideo) {
            Image(systemName: "video.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
        }
        .glassButton(cornerRadius: 21)
    }

    private var avatarButton: some View {
        Button(action: onBack) {
            avatarImage
                .frame(width: 60, height: 60)
        }
    }

    private var avatarImage: some View {
        Group {
            if let image = profile.avatar {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFill()
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.95), lineWidth: 2.5))
        .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 4.5).blur(radius: 1))
        .shadow(color: .black.opacity(0.32), radius: 12, y: 6)
    }

    private var namePill: some View {
        Button(action: onBack) {
            HStack(spacing: 4) {
                Text(profile.name)
                    .font(.system(size: 16, weight: .semibold))
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.72))
            }
            .padding(.leading, 15)
            .padding(.trailing, 9)
            .frame(height: 33)
            .foregroundColor(.white)
            .glassPanel(cornerRadius: 17)
        }
        .buttonStyle(.plain)
    }
}
