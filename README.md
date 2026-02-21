# Fluent Player

<div align="center">
  <h3>🎨 Material You 视频播放器</h3>
  <p>基于 Flutter 的现代化视频播放器，支持无感循环播放和私密保险箱</p>
  
  <p>
    <img src="https://img.shields.io/badge/Flutter-3.19-blue.svg" alt="Flutter">
    <img src="https://img.shields.io/badge/Platform-Android-green.svg" alt="Platform">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
  </p>
</div>

## ✨ 功能特性

### 🎨 Material You 设计
- **动态颜色**: 根据壁纸自动生成主题颜色
- **12种预设颜色**: 海洋蓝、青碧、翠绿、琥珀等
- **主题模式**: 浅色/深色/跟随系统
- **AMOLED深色**: 纯黑背景节省电量

### 🎬 视频播放器
- **多格式支持**: MP4, AVI, MKV, MOV, WebM 等
- **网络播放**: 支持URL直接播放
- **播放速度**: 0.25x - 2.0x 可调
- **手势控制**: 进度条拖动、音量调节

### 🔄 无感循环播放
- **零间隙循环**: 视频循环时无黑屏闪烁
- **预加载技术**: 提前800ms准备循环
- **完美衔接**: 适合背景视频、音乐MV

### 🔒 私密保险箱
- **AES加密**: 文件采用AES-256加密存储
- **密码保护**: 设置独立密码
- **文件类型**: 支持视频、图片、文档
- **安全删除**: 原文件自动删除

### ⚙️ 本地设置
- **播放位置记忆**: 下次从上次位置继续
- **主题偏好保存**: 自动记住您的选择
- **播放设置持久化**: 循环、速度等设置

## 📱 截图

| 首页 | 播放器 | 保险箱 | 设置 |
|------|--------|--------|------|
| 主界面 | 视频播放 | 加密存储 | 主题配置 |

## 🚀 快速开始

### 环境要求
- Flutter SDK 3.19+
- Android SDK 21+

### 安装运行

```bash
# 克隆仓库
git clone https://github.com/Ali-Burat/fluent-vlc-player.git
cd fluent-vlc-player

# 安装依赖
flutter pub get

# 运行
flutter run

# 构建APK
flutter build apk --release
```

## 📦 下载

从 [Releases](https://github.com/Ali-Burat/fluent-vlc-player/releases) 页面下载最新APK。

## 🛠️ 技术栈

- **Flutter** - 跨平台UI框架
- **video_player** - 视频播放
- **chewie** - 播放器UI控件
- **dynamic_color** - Material You动态颜色
- **encrypt** - AES加密
- **provider** - 状态管理
- **shared_preferences** - 本地存储

## 📄 许可证

MIT License

---

<div align="center">
  Made with ❤️ using Flutter
</div>
