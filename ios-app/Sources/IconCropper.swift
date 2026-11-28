import SwiftUI

// MARK: - 图标裁剪器
//
// 真正的裁剪：用户拖动 + 双指缩放，方框里看到什么，就是最终 1024×1024 的图标。
// 用 ImageRenderer 把这块 canvas 直接渲染成位图（圆角由系统在桌面上加，所以这里输出方图）。

struct CropTarget: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct IconCropper: View {
    let image: UIImage
    var onCancel: () -> Void
    var onDone: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var working = false

    private let box: CGFloat = 300

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("裁剪图标")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text("拖动移动位置 · 双指缩放 · 方框里就是最终图标")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            canvas
                .frame(width: box, height: box)
                .clipShape(RoundedRectangle(cornerRadius: 68, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 68, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
                .gesture(dragGesture)
                .simultaneousGesture(magnifyGesture)

            Text("提示：留一点边最好看，别把人脸顶满")
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.4))

            HStack(spacing: 12) {
                Button {
                    Haptics.fire(.tap)
                    onCancel()
                } label: {
                    Text("取消")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .glassButton(cornerRadius: 15, haptic: .tap)

                Button {
                    render()
                } label: {
                    Text(working ? "生成中…" : "用这张")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .glassButton(cornerRadius: 15,
                             tint: Palette.sendMid,
                             tintStrength: 0.78,
                             haptic: .success)
                .disabled(working)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .padding(.bottom, 6)
    }

    /// 交给 ImageRenderer 的原始画布（不带圆角、不带描边，方图 + 硬裁切）
    private var canvas: some View {
        ZStack {
            Color.black
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: box, height: box)
                .scaleEffect(scale)
                .offset(offset)
        }
        .frame(width: box, height: box)
        .clipped()
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: baseOffset.width + value.translation.width,
                                height: baseOffset.height + value.translation.height)
            }
            .onEnded { _ in baseOffset = offset }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(4, max(0.6, baseScale * value))
            }
            .onEnded { _ in baseScale = scale }
    }

    private func render() {
        working = true
        let renderer = ImageRenderer(content: canvas.frame(width: box, height: box))
        renderer.scale = 1024.0 / box     // 300pt × 3.413 ≈ 1024px
        renderer.isOpaque = true
        if let uiImage = renderer.uiImage {
            Haptics.fire(.success)
            onDone(uiImage)
        } else {
            Haptics.fire(.warning)
            onCancel()
        }
        working = false
    }
}
