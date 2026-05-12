# SafeBrowser - 安全的iOS手机浏览器

<p align="center">
  <img src="https://img.shields.io/badge/iOS-15.0%2B-blue" alt="iOS Version">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift Version">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

> 🚀 基于WebKit的高性能iOS手机浏览器，支持视频播放、阅读模式和下载管理

## ✨ 功能特性

### 🧭 基础浏览功能
- **智能地址栏** - 自动识别URL和搜索词
- **导航控制** - 前进、后退、刷新
- **进度显示** - 实时页面加载进度条
- **手势支持** - 滑动手势导航
- **分享功能** - 一键分享当前页面

### 🎬 视频播放
- **自动检测** - 智能识别页面视频
- **多种播放模式**
  - 全屏播放
  - 画中画模式 (Picture-in-Picture)
  - 内联播放
- **控制选项**
  - 播放/暂停
  - 进度条
  - 音量控制
- **投屏支持** - AirPlay投屏

### 📥 下载管理
- **视频下载** - 一键下载页面视频
- **音频下载** - 支持音频文件
- **下载管理**
  - 实时进度显示
  - 文件大小显示
  - 下载列表管理
- **文件操作**
  - 分享下载文件
  - 在Files应用中查看

### 📖 阅读模式
- **智能文章检测** - 自动识别新闻文章和博客
- **富媒体支持**
  - 文章图片展示
  - 嵌入式视频播放
- **个性化设置**
  - 字体大小调整 (A-/A+)
  - 三种主题模式
    - 💡 Light (白色)
    - 📜 Sepia (羊皮纸)
    - 🌙 Dark (深色)
  - 设置自动保存
- **阅读体验**
  - 最佳阅读宽度
  - 预估阅读时间
  - 章节标题识别

### 🔒 安全特性
- **URL验证** - 自动验证下载链接
- **安全浏览** - 阻止恶意网站
- **隐私保护** - 不追踪用户行为
- **内容安全** - WebKit安全策略

### 📱 iOS原生体验
- **响应式设计** - 适配所有iOS设备
- **深色模式** - 支持系统深色模式
- **手势操作** - 原生iOS手势支持
- **辅助功能** - 完整的VoiceOver支持

## 🛠 技术栈

### 核心框架
- **UIKit** - 用户界面
- **WebKit** - 浏览器引擎
- **AVKit** - 视频播放
- **Foundation** - 基础框架

### 第三方库
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) - 项目生成工具

### 架构设计
```
SafeBrowser/
├── Sources/
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   └── SceneDelegate.swift
│   ├── Browser/
│   │   ├── BrowserViewController.swift    # 主浏览器控制器
│   │   ├── VideoDownloadManager.swift     # 视频下载管理
│   │   └── ReadingModeManager.swift       # 阅读模式管理
│   └── Utils/
│       └── (扩展工具)
└── Resources/
    ├── Info.plist
    └── LaunchScreen.storyboard
```

## 🚀 快速开始

### 环境要求
- Xcode 15.0+
- iOS 15.0+ 部署目标
- Swift 5.9+
- macOS 13+ (Ventura)

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/yourusername/safechrome.git
   cd safechrome
   ```

2. **安装XcodeGen**
   ```bash
   # 使用Homebrew
   brew install xcodegen

   # 或使用Mint
   mint install yonaskolb/xcodegen
   ```

3. **生成Xcode项目**
   ```bash
   cd ios
   xcodegen generate
   ```

4. **打开项目**
   ```bash
   open SafeBrowser.xcodeproj
   ```

5. **运行项目**
   - 在Xcode中选择目标设备和模拟器
   - 按 `⌘+R` 或点击运行按钮

### 构建项目

#### Debug版本
```bash
cd ios
xcodebuild -project SafeBrowser.xcodeproj \
  -scheme SafeBrowser \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

#### Release版本
```bash
xcodebuild -project SafeBrowser.xcodeproj \
  -scheme SafeBrowser \
  -configuration Release \
  CODE_SIGN_IDENTITY="Your Code Sign Identity" \
  CODE_SIGNING_REQUIRED=YES \
  build
```

## 📱 使用指南

### 基础浏览
1. 在地址栏输入URL或搜索词
2. 按回车键加载
3. 使用底部工具栏导航

### 视频播放
1. 打开包含视频的网页（如YouTube）
2. 底部工具栏自动显示视频按钮
3. 点击按钮选择播放模式

### 下载视频
1. 播放视频后点击下载按钮
2. 选择"Download Page Video"
3. 等待下载完成
4. 使用分享或Files应用查看

### 阅读模式
1. 打开新闻文章或博客
2. 点击工具栏的📄按钮
3. 享受干净的阅读体验
4. 使用底部工具栏调整设置
5. 点击❌或再次点击📄退出

## 🎯 项目结构

```
ios/
├── project.yml                 # XcodeGen配置
├── SafeBrowser.xcodeproj/     # Xcode项目
├── SafeBrowser/
│   ├── Sources/
│   │   ├── App/
│   │   │   ├── AppDelegate.swift      # 应用生命周期
│   │   │   └── SceneDelegate.swift    # 场景管理
│   │   ├── Browser/
│   │   │   ├── BrowserViewController.swift  # 主控制器
│   │   │   ├── VideoDownloadManager.swift   # 下载管理
│   │   │   └── ReadingModeManager.swift     # 阅读模式
│   │   └── (其他模块)
│   └── Resources/
│       ├── Info.plist          # 应用配置
│       └── LaunchScreen.storyboard
└── SafeBrowser.xcworkspace/   # 工作空间
```

## 🔧 配置说明

### Info.plist 配置

```xml
<!-- 网络安全配置 -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
    <key>NSAllowsArbitraryLoadsForMedia</key>
    <true/>
</dict>

<!-- 后台下载 -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
```

### 项目配置 (project.yml)

```yaml
name: SafeBrowser
options:
  deploymentTarget:
    iOS: "15.0"
  xcodeVersion: "15.0"

targets:
  SafeBrowser:
    type: application
    platform: iOS
    deploymentTarget: "15.0"
```

## 🐛 常见问题

### Q: 为什么选择WKWebView而不是UIWebView？
**A:** WKWebView是Apple推荐的现代浏览器引擎，性能更好、内存占用更低、支持更多特性。

### Q: iOS为什么不能使用Chromium内核？
**A:** Apple的App Store政策要求所有浏览器必须使用WebKit引擎。这是系统限制，不是技术限制。

### Q: 如何处理视频下载被阻止的问题？
**A:** 部分网站使用DRM保护，这些视频无法下载。这是正常的版权保护。

### Q: 阅读模式无法识别某些文章？
**A:** 部分网站使用复杂的JavaScript渲染，阅读模式可能无法识别。这是技术限制，可以尝试刷新页面后重试。

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- [XcodeGen](https://github.com/yonaskolb/XcodeGen) - 项目生成工具
- [Apple Developer Documentation](https://developer.apple.com/documentation/) - 技术文档
- 所有开源社区的贡献者

---

<p align="center">
  使用 SafeBrowser，享受安全、快速的移动浏览体验 🚀
</p>
