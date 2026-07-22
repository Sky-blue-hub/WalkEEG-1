# Summer — nRF52840 WalkEEG

基于 **nRF52840 DK** 的电生理数据透传实验仓库：板端用 Zephyr/NCS 生成 8 通道测试信号并经 BLE 推送，手机端用 Flutter 实时解包、绘波形。

本阶段目标：**手机能实时看到透传数据**（测试斜坡，非真实 ADC）。

---

## 这仓库是干什么的

```
nRF52840 DK                    手机
┌─────────────────┐            ┌──────────────────┐
│  app_nus 固件    │  BLE NUS   │  mobile_walkeeg  │
│  8ch × 16bit    │  Notify    │  扫描 / 解包     │
│  @ 2 kHz 斜坡   │ ─────────► │  实时波形        │
└─────────────────┘            └──────────────────┘
```

| 目录 | 角色 | 你什么时候碰 |
|------|------|----------------|
| [`app_nus/`](app_nus/) | **板子固件**：采样定时器 + 组帧 + NUS 推流 | 改协议/信号、重新烧录 |
| [`mobile_walkeeg/`](mobile_walkeeg/) | **手机 App**：连 WalkEEG、解包、绘图 | 日常看波形、改 UI |
| [`app/`](app/) | hello_world，验证 SDK/烧录环境 | 首次搭环境 |
| [`docs/`](docs/) | 协议、联调、需求对照 | 查规范 |
| [`tools/`](tools/) | 无板子协议自检脚本 | CI / 改协议后自测 |
| [`scripts/`](scripts/) | 环境检查、同步 NCS 样例等 | 搭环境 |

**日常演示**：固件已烧好、板子有电 → 主要用 `mobile_walkeeg`。  
**改信号或协议**：两边都要动，并重新 `west flash`。

---

## 当前能力（已交付）

- 8 通道、**16-bit**、**2 kHz**（有效约 **256 kbps**）
- BLE：NUS **Notify**、大 MTU、2M PHY、短连接间隔
- 测试斜坡：约 32 秒回绕；通道间 `+ch×2000` 便于区分
- Flutter：最多 4 路同屏、Y 轴、`frames / seq / drops / loss%`
- 离线：`flutter test` + Python 协议自检

**未做（后续）**：真实心电/肌电/脑电 ADC、压缩、云端（S3/IoT/Lambda）等。

需求对照全文 → [docs/WALKEEG_README.md](docs/WALKEEG_README.md)

---

## 环境依赖

| 侧 | 需要 |
|----|------|
| 固件 | nRF Connect SDK（建议 v3.4+）、Toolchain、USB 连 DK 的 **J-Link** 口 |
| 手机 App | Flutter 3.16+、Android 真机（USB 调试）或 iOS（需 Mac） |
| 板卡目标 | 一律：`-b nrf52840dk/nrf52840` |

首次装 SDK：见 [docs/INSTALL_SDK.md](docs/INSTALL_SDK.md)，或 Cursor **nRF Connect** 面板安装。

```powershell
powershell -File scripts/check-env.ps1
```

`.vscode/settings.json` 中 `nrf-connect.topdir` 改成你的 NCS 路径（如 `C:/ncs/v3.4.0`）。

---

## 一键跑通 WalkEEG（主流程）

### 1. 烧固件（`app_nus`）

在 **nRF Connect Terminal**（或已配置 west 的 shell）中：

```powershell
cd app_nus
west build -b nrf52840dk/nrf52840 -d build_walkeeg
west flash -d build_walkeeg
```

广播名应为 **WalkEEG**。

### 2. 跑手机 App（`mobile_walkeeg`）

国内建议先设镜像（可写入用户环境变量，新开终端生效）：

```powershell
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"

cd mobile_walkeeg
flutter pub get
flutter test
flutter run
```

手机：开蓝牙 → App 点扫描 → 连接 **WalkEEG** → 看斜坡与 `loss%`。

### 3. 无板子自检

```powershell
python tools/walkeeg_protocol_selfcheck.py
python tools/walkeeg_e2e_sim.py
cd mobile_walkeeg
flutter test
```

联调细节 → [docs/WALKEEG_VERIFY.md](docs/WALKEEG_VERIFY.md)

---

## 帧协议（摘要）

| 偏移 | 字段 | 说明 |
|------|------|------|
| 0 | `magic` = `0xA5` | 帧头 |
| 1 | `version` = `0x01` | |
| 2 | `seq` u16 LE | 丢包检测 |
| 4 | `n_samples` | 本帧时间点数 N |
| 5 | `flags` | 预留 |
| 6… | `N × 8 × i16 LE` | 交错：每个时间点 8 通道 |

默认 N=20 → 帧长 326 字节。完整说明 → [docs/WALKEEG_PACKET.md](docs/WALKEEG_PACKET.md)

---

## 文档索引

| 文档 | 内容 |
|------|------|
| [docs/WALKEEG_README.md](docs/WALKEEG_README.md) | 需求对照、架构、验收标准 |
| [docs/WALKEEG_PACKET.md](docs/WALKEEG_PACKET.md) | 二进制帧协议 |
| [docs/WALKEEG_VERIFY.md](docs/WALKEEG_VERIFY.md) | 烧录 / App / 自检清单 |
| [docs/INSTALL_SDK.md](docs/INSTALL_SDK.md) | SDK 安装 |
| [docs/NUS_MOBILE_TEST.md](docs/NUS_MOBILE_TEST.md) | 旧版 NUS 手机测试 |
| [docs/MESH.md](docs/MESH.md) | Mesh 相关笔记 |
| [mobile_walkeeg/README.md](mobile_walkeeg/README.md) | Flutter App 专用说明 |

---

## 其它入口（可选）

**hello_world（验证烧录）：**

```powershell
cd app
west build -b nrf52840dk/nrf52840 -d build
west flash -d build
```

**从 NCS 同步 peripheral_uart 源码：**

```powershell
powershell -File scripts/sync-from-ncs.ps1
```

Cursor Tasks：`Check environment` / `Build hello_world` / `Flash NUS` 等。

---

## 常见问题

| 问题 | 处理 |
|------|------|
| `west` 找不到 | 用 **nRF Connect Terminal**，勿用未加载 NCS 的普通 PowerShell |
| 扫不到 WalkEEG | 确认已 `west flash -d build_walkeeg`、板子有电、等复位完成后再扫 |
| Flutter 卡在 Gradle / Google 下载 | 设 `FLUTTER_STORAGE_BASE_URL` / `PUB_HOSTED_URL` 国内镜像后**新开终端** |
| 通道曲线看起来一样 | 需烧录含 `ch×2000` 偏移的固件；同屏多选 CH0 与 CH7 对比 |
| App 一直 Scanning | 更新后的 App 约 12s 超时；仍失败看状态行原文 |

---

## 学习资料

- [BLE GAP](https://learn.adafruit.com/introduction-to-bluetooth-low-energy/gap)
- [GATT](https://software-dl.ti.com/lprf/sdg-latest/html/ble-stack-3.x/gatt.html)
- [Zephyr](https://docs.zephyrproject.org/latest/introduction/introduction.html)
- [NCS 安装](https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/nrf/installation/install_ncs.html)
- [nRF52840 DK](https://docs.zephyrproject.org/latest/boards/nordic/nrf52840dk/doc/index.html)
