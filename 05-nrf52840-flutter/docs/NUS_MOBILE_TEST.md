# 手机测试 NUS 蓝牙串口

## 前置条件

- `app_nus` 已编译并烧录到 nRF52840 DK
- 板子 LED1 应每秒闪烁（运行中）
- 板子广播名称：**WalkEEG**（旧固件可能仍为 Nordic_UART_Service）

## 步骤

### 1. 安装 app

- **Android / iOS**：搜索 **nRF Connect**（Nordic Semiconductor 官方）

### 2. 扫描并连接

1. 打开 nRF Connect → **Scanner** 标签
2. 找到 **WalkEEG**
3. 点击 **CONNECT**
4. 启用 TX Notify 后应看到二进制流（首字节 `A5`）；完整协议见 [WALKEEG_PACKET.md](WALKEEG_PACKET.md)

### 3. 打开 NUS Service

1. 连接成功后展开服务列表
2. 找到 **Unknown Service** 或 UUID 以 `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` 开头
3. 这就是 **Nordic UART Service (NUS)**

### 4. 收发数据

| Characteristic | UUID 前缀 | 方向 | 操作 |
|----------------|-----------|------|------|
| RX | `6E400002-...` | 手机 → 板子 | 点向上箭头发送文字 |
| TX | `6E400003-...` | 板子 → 手机 | 启用（通知图标），接收数据 |

### 5. 验证成功

- 手机发送 "Hello" → RTT 出现 `Received N bytes ...: hello`；PuTTY/COM6 也应显示 `hello`
- 板子通过串口输入 + Enter → 手机 TX Notify 收到数据

### 6. PuTTY / COM6 串口（115200）

1. **先** 打开 PuTTY（Serial，J-Link 的 COM 口，115200）
2. **再** 按板子 RESET
3. 应看到 `Starting Nordic UART service sample`
4. 若 COM6 一直空白，确认已烧录含 `CONFIG_UART_CONSOLE=n` 的 `app_nus` 固件

### 7. 手机写入注意

- 只用 RX 特征（`6e400002`）旁的 **Write ↑**，不要用 Macro 录制
- RTT 若出现 `Unhandled ATT code 0x16`，说明用了 Prepare Write，需断开重连并用普通 Write

## 对应 BLE 概念

- **GAP**：板子作为 Peripheral 广播，手机作为 Central 扫描连接
- **GATT**：NUS 是一个 Service，RX/TX 是两个 Characteristic

## 故障排查

| 问题 | 解决 |
|------|------|
| 扫不到设备 | 确认固件已烧录、板子未进入睡眠、蓝牙已开启 |
| 连接后立即断开 | 检查是否启用了配对/安全，尝试清除手机蓝牙缓存 |
| 收不到 Notify | 确认已对 TX Characteristic 启用 Notify（通知图标） |
| 看不到 log | 安装 J-Link RTT Viewer 或使用 nRF Connect 扩展 RTT 面板 |
| RTT 报 `Unhand Notifyled ATT code 0x16` | nRF Connect 误开了 **Reliable Write**（Macro 录制后常见）。见下方「Reliable Write 修复」 |
| PuTTY/COM6 空白 | 确认烧录含 `CONFIG_UART_CONSOLE=n` 的固件；先开 PuTTY 再 RESET |

## Reliable Write 修复（ATT 0x16）

这是 **手机 App 写入方式错了**，重装 App 后若仍用 Reliable Write 仍会报错。

1. 连接设备后，在 CLIENT 页面向下找 **Reliable write** 区域
2. 若显示进行中，点 **Abort**（中止）
3. 右上角 **⋮** → **Refresh services**（刷新服务）
4. **⋮** → **Enable CCCDs**（打开 TX Notify）
5. 点 RX 的 **↑** 写数据时：
   - 选 **Text**，输入 `hello`
   - 写入类型用 **Write** 或 **Write without response**
   - **不要** 点 Reliable write 的 Begin
   - **不要** 用 Macro 红色录制

可选：App **Settings → Connectivity** → 打开 **Abort reliable write on connection**（若有此项）。

仍不行可换 **Serial Bluetooth Terminal**（Android）连接 NUS，比手动 GATT 写更省事。
