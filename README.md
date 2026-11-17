# AI Chat

一个 SwiftUI 编写的 iOS 聊天客户端：自己填 Base URL 和 API Key，用 OpenAI 协议和任意兼容服务对话。构建全程不签名、不需要证书，由 GitHub Actions 产出未签名 IPA。

## 设计

- **只用黑白灰**：背景、文字、气泡、按钮全部是灰阶，没有任何彩色。
- **浅色背景 `#F2F4ED`**（微暖的米白）；深色背景 `#0C0C0C`。所有颜色由 `Palette` 的动态色统一提供，跟随系统实时切换。
- **极简**：没有引导页、说明文字和提示弹窗。首屏只有标题、两个图标；空状态是一个细线加号。
- **统一对齐**：左右统一 20pt 边距；标题、列表、气泡、输入框共用同一条左边线；对话列表用发丝线分隔，不用卡片和阴影。
- **排版**：系统字体；标题 30pt；正文 16pt、行距 6；次要信息 11–13pt。
- **图标**：白底 CHAT 字标（黑 / 灰双色），已生成全套 iPhone 尺寸与 1024 营销图。
- 用户消息是深色圆角气泡（深色模式下为浅灰气泡），AI 回复不加气泡，直接铺在背景上。

## 功能

- 输入 **Base URL**（如 `https://api.openai.com/v1`，也接受完整 `/chat/completions` 地址）和 **API Key**，按 OpenAI 协议聊天。
- **流式输出**：边生成边显示；生成中可点按钮停止。
- **API Key 本地加密存储**：优先写入 Keychain；未签名安装缺少 Keychain 权限时，自动退回受数据保护的应用私有文件（不写入聊天记录文件，也不进 iCloud 备份）。
- **多服务商**：可以添加任意多个服务（名称、Base URL、模型、Key），对话中可以随时切换。
- **模型列表**：编辑服务时可从 `/models` 拉取模型列表直接选择，也可以手填。
- **聊天记录本地保存**：每个会话的完整消息持久化，下次打开继续聊；发送时自动带上最近上下文。
- **删除聊天记录**：列表左滑删除会话；会话菜单里删除当前对话；服务页可一键清空全部对话。
- 跟随系统浅色 / 深色模式；自适应安全区与键盘。

## 使用

1. 点右上角滑块图标 → 加号，填名称、Base URL、模型、API Key，保存。
2. 返回，点右上角加号新建对话。
3. 输入内容发送；长按 / 选中可复制回复。
4. 会话右上角 `…` 可切换服务商或删除当前对话；会话列表左滑删除。

Base URL 规则：直接拼在后面的路径是 `/chat/completions`，所以地址要写到版本号，例如 `https://api.openai.com/v1`。如果要连的网关本身有独立路径（如 `https://example.com/openai/v1`），填到 `v1` 为止。

## 结构

```
.
├── .github/workflows/build.yml          # CI：生成工程 → archive → 打包 → 上传未签名 IPA
├── Sources/MyApp/
│   ├── App.swift                        # 入口与导航
│   ├── Theme.swift                      # 动态黑白灰调色板与间距
│   ├── Models.swift                     # 服务商 / 会话 / 消息模型
│   ├── AppStore.swift                   # 状态、持久化、请求编排
│   ├── OpenAIService.swift              # OpenAI 协议（流式、模型列表）
│   ├── SecretStore.swift                # Keychain + 文件兜底
│   ├── ConversationListView.swift       # 对话列表
│   ├── ChatView.swift                   # 对话页
│   ├── ProvidersView.swift              # 服务列表
│   ├── ProviderEditor.swift             # 服务编辑
│   └── Assets.xcassets/                 # App 图标（由 Design/Chatgo.png 生成）
├── Design/
│   ├── Chatgo.png                       # 图标原图
│   └── make_icons.py                    # 图标尺寸生成脚本
├── Info.plist
└── project.yml                          # XcodeGen 工程描述
```

## 构建

推送 `main` 自动构建，也可以在 **Actions → Build Unsigned IPA → Run workflow** 手动触发；产物在运行页面的 **Artifacts → MyApp-unsigned-ipa** 下载。

本地构建（需要 macOS + Xcode + XcodeGen）：

```sh
brew install xcodegen
xcodegen generate
xcodebuild archive -project MyApp.xcodeproj -scheme MyApp \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/MyApp.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

mkdir -p Payload
cp -R build/MyApp.xcarchive/Products/Applications/MyApp.app Payload/
zip -qry MyApp-unsigned.ipa Payload
```

## 安装

产出的是未签名 IPA：构建全程不需要任何证书或签名。

- TrollStore 等支持未签名包的安装器：直接安装；
- AltStore / Sideloadly：按工具流程装入；
- 未签名包无法上架 App Store，仅用于自测；请确认你拥有设备与账号的合法使用权。

## 隐私

- 聊天内容仅保存在 App 沙盒内；API Key 不写入会话文件，也不出现在任何日志里。
- 请求只发往你自己填写的 Base URL，不经过第三方中转。
