# 萌哩手机客户端

萌哩手机客户端是”萌哩“设计的独立Android应用，以小巧的体积和简洁的界面给用户带来良好的使用体验。应用内加入了一些实用功能，用户可以通过应用便捷地访问”萌哩“网站。

本仓库是萌哩手机客户端（Moely Mobile）的全部代码。喜欢的话给个Star支持一下吧！

[应用官网](https://mobile.moely.link/) | [萌哩官网](https://www.moely.link/)

## 特性

- 安装包仅10M，小巧轻便
- 不记录浏览历史，安全隐私
- 内置下载管理器，便于查看下载内容
- 支持修改主题模式，自定义主题色
- 网页翻译功能，支持多个翻译引擎，同时显示原文和译文

开发不易，喜欢的给个Star支持下吧！

## 技术栈

- Java：应用主要架构和功能实现
- Android System Webview：网页内容渲染
- JavaScript：处理部分网页功能

## 项目结构

```txt
moely-mobile/
├── app/
│   ├── src/main/     # 应用架构
│   │   ├── java/link/moely/mobile/
│   │   │   ├── MainActivity.java     # 应用主进程
│   │   │   ├── BaseActivity.java     # 初始化主题
│   │   │   ├── DownloadActivity.java # 下载服务
│   │   │   ├── DownloadItem.java     # 下载条目
│   │   │   ├── DownloadAdapter.java  # 下载状态
│   │   │   ├── SettingsActivity.java # 设置
│   │   │   ├── ThemeManager.java     # 修改主题色
│   │   │   ├── ThemeModeManager.java # 颜色模式切换
│   │   │   ├── ThemeUtils.java       # 应用主题
│   │   │   ├── TranslationEngine.java # 翻译服务
│   │   │   └── UpdateChecker.java    # 检查更新
│   │   ├── res/      # 资源文件
│   │   │   ├── drawable/      # 图标文件
│   │   │   ├── layout/        # 界面布局
│   │   │   ├── values/
│   │   │   │   ├── colors.xml   # 浅色模式颜色
│   │   │   │   ├── themes.xml   # 浅色模式主题
│   │   │   │   └── strings.xml  # 界面说明文字
│   │   │   └── values-night/  # 深色模式颜色和主题
│   │   └── AndroidManifest.xml  # 清单文件
│   └── build.gradle     # 核心构建脚本
├── build.gradle     # 构建设置
└── settings.gradle  # 项目配置
```

## 开源协议

本项目采用 [GPL-3](https://github.com/moelylink/moely-mobile/blob/main/LICENSE) 许可证，使用代码请遵守开源协议。
