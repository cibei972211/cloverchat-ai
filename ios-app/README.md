# CloverChat — 原生 SwiftUI iOS App

纯 **SwiftUI** 实现的 AI 聊天应用（无 WebView），包含：

- Liquid Glass 风格 UI（ultraThinMaterial + 镜面流光 + 折边描边），iOS 26 设备上自动获得系统级玻璃质感
- 名字 / 头像（相册选取）/ 聊天背景（3 预设 + 自定义上传）完全自定义
- 内置「小树」人格回复引擎，支持接入任意 OpenAI 兼容接口（SSE 流式）
- 语音听写（Speech 框架）、模拟视频通话页
- 消息 / 设置本地持久化（UserDefaults + Documents）

## 目录

```
ios-app/
├── project.yml          # XcodeGen 工程定义
├── Sources/             # 全部 Swift 源码
│   ├── CloverChatApp.swift
│   ├── RootView.swift   # 主界面（顶栏/消息/输入条）
│   ├── Sheets.swift     # 操作/背景/设置/消息面板
│   ├── CallScreen.swift # 通话页
│   ├── ChatModel.swift  # 消息与流式回复
│   ├── APIClient.swift  # OpenAI 兼容 SSE 客户端
│   ├── PersonaEngine.swift
│   ├── ProfileModel.swift
│   ├── SpeechRecognizer.swift
│   └── GlassStyle.swift
└── Assets.xcassets      # 头像与背景图
```

## 构建 IPA

### 方式一：本机（需 macOS + Xcode）

```bash
brew install xcodegen
cd ios-app
xcodegen generate
open CloverChat.xcodeproj   # 选签名 Team → Product → Archive
```

### 方式二：GitHub Actions 自动构建

推送后运行 workflow「Build iOS IPA」，在 Actions 页面下载 `CloverChat-ipa` artifact，
得到**未签名 IPA**，再用 Sideloadly / AltStore / TrollStore 签名安装。
