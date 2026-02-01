# Quickstart: Session Timer

**Feature Branch**: `001-session-timer`  
**Date**: 2026-02-01

## Prerequisites

- **macOS**: Ventura 13.0+ 或更高版本
- **Xcode**: 16.0+ (支持 Swift 6)
- **Homebrew**: 用于安装构建工具
- **iOS Simulator/Device**: iOS 16.1+ (Live Activities 最低要求)
- **Apple Developer Account**: 用于 iCloud 和 Push Notifications

## Install Build Tools

```bash
# 安装 XcodeGen (项目生成工具)
brew install xcodegen

# 安装 xcbeautify (构建输出美化)
brew install xcbeautify

# 验证安装
xcodegen --version
xcbeautify --version
```

## Project Setup

### 1. Clone and Generate Project

```bash
cd /Users/shanehou/Developer/Projects/SessionTimer/src

# 生成 Xcode 项目
xcodegen generate

# 或使用 Makefile
make generate
```

### 2. Open in Xcode (Optional)

```bash
# 如果需要在 Xcode 中打开
cd /Users/shanehou/Developer/Projects/SessionTimer/src
open SessionTimer.xcodeproj
```

### 3. Configure Signing

首次运行需要在 Xcode 中配置签名：

1. 打开 `src/SessionTimer.xcodeproj`
2. 选择 `SessionTimer` target
3. 在 **Signing & Capabilities** 中选择你的 Team
4. 同样配置 `SessionTimerWidgets` target

> **Note**: 签名信息存储在本地，不纳入版本控制

---

## Build Commands

> **Note**: 所有构建命令都在 `src/` 目录下执行

### 使用 Makefile (推荐)

```bash
cd src

# 生成项目
make generate

# 构建 (Debug)
make build

# 运行到模拟器
make run-simulator

# 运行到真机 (自动检测设备)
make run-device

# 运行测试
make test

# 清理构建产物
make clean

# 查看所有可用命令
make help
```

### 使用脚本

```bash
cd src

# 生成项目
./scripts/generate.sh

# 构建并运行到自动检测的设备
./scripts/run.sh

# 指定设备运行
./scripts/run.sh "iPhone 15 Pro"

# 运行测试
./scripts/test.sh
```

### 直接使用 xcodebuild

```bash
cd src

# 列出可用设备
xcrun xctrace list devices

# 构建 (Debug, 模拟器)
xcodebuild -project SessionTimer.xcodeproj \
           -scheme SessionTimer \
           -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
           build | xcbeautify

# 构建并运行到真机
xcodebuild -project SessionTimer.xcodeproj \
           -scheme SessionTimer \
           -destination 'platform=iOS,name=你的设备名' \
           build | xcbeautify
```

---

## Project Structure

```
.
├── specs/                           # 规格文档
├── src/                             # 主 App 源码 + 构建配置
│   ├── project.yml                  # XcodeGen 配置 (项目真相来源)
│   ├── Makefile                     # 构建命令快捷方式
│   ├── scripts/
│   │   ├── generate.sh              # 生成 Xcode 项目
│   │   ├── build.sh                 # 编译项目
│   │   ├── run.sh                   # 编译并运行
│   │   └── test.sh                  # 运行测试
│   ├── App/
│   ├── Models/
│   ├── Views/
│   ├── ViewModels/
│   ├── Services/
│   ├── Extensions/
│   ├── Shared/                      # 与 Widget 共享的代码
│   ├── Resources/
│   └── SessionTimer.xcodeproj/      # 由 XcodeGen 生成 (gitignore)
└── src-widgets/                     # Widget Extension 源码
```

---

## project.yml Configuration

`src/project.yml` 是项目的"单一真相来源"，定义了：

- Targets (SessionTimer, SessionTimerWidgets)
- Build Settings
- Dependencies
- Capabilities (iCloud, Background Modes, etc.)

修改项目配置时，编辑 `src/project.yml` 然后运行 `make generate`。

```yaml
# src/project.yml 示例结构
name: SessionTimer
options:
  bundleIdPrefix: me.melkor
  deploymentTarget:
    iOS: "16.1"

targets:
  SessionTimer:
    type: application
    platform: iOS
    sources:
      - App
      - Models
      - Views
      - ViewModels
      - Services
      - Extensions
      - Shared
      - Resources
    settings:
      SWIFT_VERSION: "6.0"
    # ...
    
  SessionTimerWidgets:
    type: app-extension
    platform: iOS
    sources:
      - path: ../src-widgets
    # ...
```

---

## Workflow

### 日常开发流程

```bash
# 1. 拉取最新代码
git pull

# 2. 进入 src 目录
cd src

# 3. 重新生成项目 (如果 project.yml 有变更)
make generate

# 4. 编写代码 (直接在 src/ 下添加/修改文件)

# 5. 运行到设备
make run-device

# 6. 提交代码 (无需提交 .xcodeproj)
git add .
git commit -m "feat: add new feature"
```

### 添加新文件

1. 在 `src/` 下对应目录创建新的 `.swift` 文件
2. 运行 `make generate` 重新生成项目
3. 文件自动添加到 Xcode 项目中

> **Note**: XcodeGen 会自动扫描 `sources` 目录下的所有文件，无需手动添加

---

## Capabilities Configuration

在 `src/project.yml` 中配置 Capabilities：

```yaml
targets:
  SessionTimer:
    entitlements:
      path: App/SessionTimer.entitlements
    settings:
      CODE_SIGN_ENTITLEMENTS: App/SessionTimer.entitlements
    attributes:
      SystemCapabilities:
        com.apple.BackgroundModes:
          enabled: 1
        com.apple.Push:
          enabled: 1
        com.apple.iCloud:
          enabled: 1
```

---

## Testing

### 单元测试

```bash
make test
```

### UI 测试

```bash
make test-ui
```

### 在特定设备上测试

```bash
./scripts/test.sh "iPhone 15 Pro"
```

---

## Common Issues

### 1. `xcodegen` command not found

```bash
brew install xcodegen
```

### 2. 签名错误

首次运行需在 Xcode 中配置 Team：
1. 打开 `src/SessionTimer.xcodeproj`
2. 选择 target → Signing & Capabilities → 选择 Team

### 3. 找不到设备

```bash
# 列出所有可用设备
xcrun xctrace list devices

# 确保设备已连接并信任此电脑
```

### 4. Live Activity 不显示

- 需要在真机上测试
- 确保 Info.plist 中有 `NSSupportsLiveActivities = YES`

---

## Next Steps

1. ✅ 安装构建工具 (`xcodegen`, `xcbeautify`)
2. ✅ 生成项目 (`make generate`)
3. ✅ 配置签名 (Xcode → Signing & Capabilities)
4. ⬜ 运行 `/speckit.tasks` 生成实现任务
5. ⬜ 按任务顺序实现功能

---

## Resources

- [XcodeGen Documentation](https://github.com/yonaskolb/XcodeGen)
- [xcbeautify Documentation](https://github.com/cpisciotta/xcbeautify)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
