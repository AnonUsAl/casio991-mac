# fx-991CN X 科学计算器 — macOS 版

与 Android 版同源的 macOS 原生应用。用 Swift + WKWebView 封装网页版模拟器，原机 ROM 与 WASM 内核全部内置，**完全离线、免费、无广告**。

## 使用

双击 `Casio991.app` 即可运行（已 ad-hoc 签名并去除隔离属性）。若从别处拷贝后系统提示"无法打开"，在终端执行：

```bash
xattr -dr com.apple.quarantine /path/to/Casio991.app
```

### 安装 / 更新 / 卸载

- **安装或更新**：双击 `安装.command`——它会关闭旧版、彻底覆盖安装到「应用程序」，并校验是否为最新版（按键清晰）。
- **彻底卸载**：双击 `卸载.command`——会把 app **连同计算记忆（WKWebView localStorage）、缓存一起移入废纸篓**（可恢复）。手动卸载只删 app 会残留这些数据。

## 特性

- 原生 macOS 窗口，深色主题，与 Android 版一致的开屏署名
- 内置本地 HTTP 服务（只监听 127.0.0.1 随机端口），把资源以同源 http 供给 WKWebView，绕开 WASM/fetch 的跨域限制
- 计算记忆保存在 WKWebView 本地存储中
- 零第三方依赖，仅用系统 Cocoa + WebKit 框架

## 自己构建

需要 macOS + Xcode 命令行工具（Swift 6+）：

```bash
./build.sh
```

脚本会：复制站点资源 → 生成 .icns 图标 → swiftc 编译 → 组装 .app → ad-hoc 签名 → 打包 zip。

## 版权 / 免责声明

非 Casio 官方产品。计算器固件、机身与品牌归原权利人（卡西欧）所有；底层模拟内核来自开源项目 CasioEmuNeo（GPL-3.0），网页版来自 WENGENG-boop/fx991cnx-web。仅作个人学习与备份用途。
