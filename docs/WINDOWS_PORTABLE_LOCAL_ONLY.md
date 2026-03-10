# Windows 便携版（本地模式）构建说明

## 目标

生成一个无需注册登录、仅走本地后端处理的 Windows 便携包。

该模式会：

- 跳过桌面首启向导和登录流程
- 禁用 SaaS/云端路由，仅使用本地后端
- 本地后端不启用 `security.enableLogin`

## 前置条件

- Windows 10/11 x64
- JDK 21+（必须有 `java` 和 `jlink`）
- Node.js + npm（建议 Node 20+）
- Rust stable（MSVC 工具链）+ Cargo
- Visual Studio Build Tools（C++ 桌面构建组件，需可用 `cl.exe` / `link.exe`）
- PowerShell（用于 zip 打包）

目标机器运行时还需要：

- Microsoft Edge WebView2 Runtime（系统通常自带；若无则需先安装）

## 先做依赖预检

在仓库根目录执行：

```bat
scripts\check-windows-portable-prereqs.bat
```

若有 `[FAIL]`，先按提示补齐依赖再继续。

## 一键构建命令

在仓库根目录执行：

```bat
scripts\build-windows-portable-local-only.bat
```

脚本会自动完成：

1. 构建后端 JAR 并生成 jlink 精简 JRE
2. 以本地便携模式构建 Tauri（`--no-bundle`）
3. 组装便携目录并打包 zip

## 输出位置

- 便携目录：`frontend\src-tauri\target\portable\Stirling-PDF-portable`
- 压缩包：`frontend\src-tauri\target\portable\Stirling-PDF-portable.zip`

## GitHub Actions 一键打包（Windows）

仓库已提供手动触发的工作流：

- 文件：`.github/workflows/windows-portable-local-only.yml`
- 名称：`Build Windows Portable (Local-Only)`

使用方法：

1. 将分支推送到 GitHub
2. 打开仓库 `Actions` 页面
3. 选择 `Build Windows Portable (Local-Only)`，点击 `Run workflow`
4. 构建完成后，在该次运行的 `Artifacts` 下载 `Stirling-PDF-portable-local-only-windows-x86_64`

## 说明

- 该模式会设置 `VITE_DESKTOP_LOCAL_ONLY=true`
- 为保证桌面壳能力，前端构建阶段使用 `DISABLE_ADDITIONAL_FEATURES=false`
- 后端 JAR 仍由 `build-tauri-jlink.bat` 按当前脚本逻辑生成（`DISABLE_ADDITIONAL_FEATURES=true`）
- 便携启动脚本会把 `APPDATA`/`LOCALAPPDATA`/`PROGRAMDATA` 和 `WEBVIEW2_USER_DATA_FOLDER` 指向便携目录下 `data\`，避免写入系统用户目录
