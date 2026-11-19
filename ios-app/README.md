# CloverChat iOS 工程（产出 .ipa）

一个原生 iOS 壳（WKWebView）+ 网页聊天界面的混合应用。用户可在 App 内自定义
名字 / 头像 / 背景，网页部分与本仓库根目录的 Web 版完全同步（`www/`）。

## 目录结构

```
ios-app/
├── project.yml          # XcodeGen 工程描述
├── Sources/
│   ├── AppDelegate.swift   # 入口 + WKWebView 控制器
│   └── Info.plist          # xcodegen 自动生成
└── www/                 # 网页资源（打包进 App）
```

## 方式一：自己有 Mac + Xcode（推荐，可直接签名）

```bash
brew install xcodegen
cd ios-app
xcodegen generate          # 生成 CloverChat.xcodeproj
open CloverChat.xcodeproj
```

在 Xcode 中：

1. 选中 App target → Signing & Capabilities → 勾选 Automatically manage signing，选择你的开发者账号
   （免费 Apple ID 也可以，Bundle ID 改成唯一的，如 `com.你的名字.cloverchat`）
2. 连接 iPhone，直接 Run；或 `Product → Archive → Distribute App` 导出 `.ipa`

## 方式二：没有 Mac —— 用 GitHub Actions 云端构建（免费）

1. 把整个项目推到一个 GitHub 仓库（需要 `.github/workflows/build-ipa.yml` 在仓库根目录）
2. 仓库页 → Actions → `Build iOS IPA` → Run workflow
3. 构建完成后在 Artifacts 里下载 `CloverChat-unsigned-ipa`（未签名 IPA）

## 未签名 IPA 怎么装到手机（三选一）

| 方式 | 条件 | 说明 |
|------|------|------|
| Sideloadly | 电脑 + 数据线 + 免费 Apple ID | 免费证书 7 天有效，到期重签 |
| AltStore | 电脑 + 免费 Apple ID | 同上，可自动续签 |
| TrollStore | iOS 14.0–16.6.1 / 17.0 | 永久签名，无需开发者账号 |

付费开发者账号（$99/年）可以用 Xcode 直接导出分发签名，或上传 TestFlight。

## 修改 App 名称 / 图标 / Bundle ID

- 名称：`ios-app/project.yml` → `CFBundleDisplayName`
- Bundle ID：`project.yml` → `PRODUCT_BUNDLE_IDENTIFIER`
- 图标：在 Xcode 里添加 Assets（或把 `www/assets/icon-512.png` 放进 AppIcon）

## 注意

- App 内「AI 设置」填的接口地址、Key、头像、背景等只保存在手机本地（WKWebView localStorage）
- 已在 Info.plist 中允许 HTTP 接口（NSAllowsArbitraryLoads），方便接本地/自建模型
