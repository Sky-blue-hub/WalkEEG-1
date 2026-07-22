# SDK 安装指南（首次必做）

当前检测到 **NCS 尚未安装**（`C:\ncs` 不存在）。请按以下步骤完成，然后继续编译。

## 步骤

### 1. 连接硬件

- nRF52840 DK 用 USB 连接 **J-Link 接口**（板上标注 J-Link 的 USB 口）
- Windows 设备管理器应出现 J-Link 相关设备

### 2. 安装 Toolchain

1. 打开 Cursor
2. 左侧点击 **nRF Connect** 图标
3. 点击 **Manage toolchains**
4. 选择 **Install Toolchain**
5. 选择 stable 版本（与 SDK 版本匹配，如 v2.9.0）

### 3. 安装 SDK

1. 在同一面板点击 **Manage SDKs**
2. 选择 **Install SDK**
3. 选择 **nRF Connect SDK**（不要选 Bare Metal）
4. 选择版本（建议 latest stable）
5. 等待下载完成（30–60 分钟，2–4 GB）

### 4. 验证安装

安装完成后，在 PowerShell 中运行：

```powershell
cd e:\projects\business\summer
powershell -File scripts/check-env.ps1
powershell -File scripts/update-settings.ps1
```

应看到 SDK 路径和 west 工具均 OK。

### 5. 继续编译

在 **nRF Connect Terminal** 中（重要！）：

```powershell
cd e:\projects\business\summer\app
west build -b nrf52840dk/nrf52840 -d build
west flash -d build
```

## 安装完成后的一键流程

```powershell
cd e:\projects\business\summer
powershell -File scripts/update-settings.ps1
powershell -File scripts/sync-from-ncs.ps1
powershell -File scripts/build.ps1 -App app -Board nrf52840dk/nrf52840
powershell -File scripts/flash.ps1 -App app -Board nrf52840dk/nrf52840
powershell -File scripts/build.ps1 -App app_nus -Board nrf52840dk/nrf52840
powershell -File scripts/flash.ps1 -App app_nus -Board nrf52840dk/nrf52840
```

手机测试见 [docs/NUS_MOBILE_TEST.md](NUS_MOBILE_TEST.md)。
