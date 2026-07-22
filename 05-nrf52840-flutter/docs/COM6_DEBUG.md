# COM6 收发失败 — 逐步定位

RTT 能收发、COM6 不行时，按下面 **从板子到 PC** 一层层测。每步有 **通过标准**，失败即停在该层。

```
手机 ←BLE→ nRF52840 固件 ←uart0→ J-Link 芯片 ←USB→ Windows COM6 ←→ PuTTY/终端
         ↑ RTT 能看到                              ↑ 问题多半在这里
```

---

## 第 0 步：确认 COM 口没错

**操作：** 设备管理器 → 端口 → 找 **JLink CDC UART Port (COM6)**

| 结果 | 说明 |
|------|------|
| ✅ 只有 J-Link 是 COM6 | 继续 |
| ❌ COM6 是别的芯片 / 多个 COM | PuTTY 必须选 J-Link 那个 |

---

## 第 1 步：固件 → uart0 引脚（板子侧 TX）

**操作：** 开 RTT → RESET 板子

**RTT 应出现：**
```text
UART welcome queued (37 bytes)
UART TX done, 37 bytes
```

| 结果 | 说明 |
|------|------|
| ✅ 有 `UART TX done` | 固件认为已从 uart0 发出 → **第 1 步通过** |
| ❌ 没有 / 有 err | 固件问题，查编译是否最新 `app_nus` |

---

## 第 2 步：J-Link → Windows COM6（PC 是否收到 TX）

**操作（关键顺序）：**

1. **关掉** Cursor 里 COM6 和 RTT（避免占端口）
2. 只开 **PuTTY**：Serial，**COM6**，**115200**，Flow control **None**
3. PuTTY 点 **Open**
4. **再按** 板子 RESET

**PuTTY 应出现：**
```text
Starting Nordic UART service sample
```

| 结果 | 说明 |
|------|------|
| ✅ PuTTY 有欢迎语 | COM6 **接收** 正常 → 跳到第 4 步 |
| ❌ RTT 有 TX done，PuTTY 仍空白 | **断在第 2 步**：J-Link VCOM → PC |

### 第 2 步失败时排查

1. USB 必须插开发板 **J-Link 口**（标 IF / DEBUG），不是别的口
2. 打开 **J-Link Configurator**（开始菜单搜 SEGGER）→ 连接板子 → 勾选 **Virtual COM Port** → Apply
3. 设备管理器 → **JLink CDC UART Port (COM6)** → 右键卸载设备 → 拔插 USB
4. PuTTY 先 Open，等 5 秒：新固件每 3 秒发 `UART heartbeat`（不必 RESET）
5. **不要** 同时开 RTT 和 PuTTY 试一次（只 PuTTY）
6. 换 USB 线 / USB 口（接主板后置 USB 口）

### 仍全黑 — 按顺序做

#### 1. J-Link Configurator（必做）

1. 开始菜单 → **J-Link Configurator**
2. USB 连板子 **J-Link 口** → 应识别到 nRF52840
3. 勾选 **Virtual COM Port** → **Apply**
4. 拔插 USB

#### 2. 重装 SEGGER 驱动

1. 设备管理器 → **JLink CDC UART Port (COM6)**
2. 右键 → **卸载设备**（勾选删除驱动）
3. 安装 [SEGGER J-Link 软件包](https://www.segger.com/downloads/jlink/)（含驱动）
4. 重新插 USB，确认 COM 口重新出现

#### 3. 用脚本测 COM6（关 PuTTY 后）

```powershell
powershell -ExecutionPolicy Bypass -File e:\projects\business\summer\scripts\test-com6.ps1
```

- 输出 `OK: Received data` → COM 通，PuTTY 配置问题
- 输出 `FAIL: No data` → J-Link VCOM 硬件/驱动仍不通

#### 4. 确认 USB 口

nRF52840 DK 只有 **一个 J-Link USB**（标 **IF** / **J-Link**）。  
不要插 Power/Battery 口或其它排针上的 5V。

#### 5. 备用：外接 USB 串口线（推荐）

J-Link VCOM 修不好时，用 **CP2102/CH340** 接 Arduino 口：

| USB 串口模块 | nRF52840 DK |
|-------------|-------------|
| TX          | **D0** (P0.29) |
| RX          | **D1** (P0.31) |
| GND         | GND |

编译烧录：

```powershell
cd e:\projects\business\summer\app_nus
west build -b nrf52840dk/nrf52840 -d build -- "-DEXTRA_CONF_FILE=boards/uart1_usb_serial.conf"
west flash -d build --runner jlink
```

PuTTY 连 **USB 串口模块的 COM 口**（不是 COM6）。

#### 6. 学习阶段可只用 RTT

若暂时无 USB 串口线：手机 ↔ 板子 **已在 RTT 验证成功**（`Received ...: hello`）。  
NUS 功能正常，只是 PC 虚拟串口 COM6 不可用；**可继续用 RTT 做蓝牙串口实验**。

---

## 第 3 步：Windows COM6 → 固件（PC 发送 / RX）

**操作：**

1. PuTTY 保持打开
2. 可选：再开 RTT（与 PuTTY 同时）
3. 手机连 NUS，TX 开 Notify
4. 在 **PuTTY** 输入 `test` 并按 **Enter**

**RTT 应出现：**
```text
UART RX from COM: test
```

**手机 TX Notify 应收到：** `test`（或带换行）

| 结果 | 说明 |
|------|------|
| ✅ RTT 有 `UART RX from COM` | COM6 **发送** 正常 |
| ❌ RTT 没有 | **断在第 3 步**：PC → J-Link → 板子 RX |

### 第 3 步失败时排查

1. PuTTY：**Connection → Serial → Flow control = None**
2. 确认按了 **Enter**（固件要 `\r` 或 `\n` 才转发 BLE）
3. 只开一个程序占用 COM6

---

## 第 4 步：手机 → 固件 → COM6（完整下行）

**操作：** PuTTY 已开 → 手机 RX Write 发 `hello`

| 检查点 | 通过标准 |
|--------|----------|
| RTT | `Received N bytes ...: hello` |
| RTT | `UART TX done, N bytes` |
| PuTTY | 显示 `hello` |

| 结果 | 说明 |
|------|------|
| RTT 两行都有，PuTTY 有 hello | **全链路 OK** |
| RTT 都有，PuTTY 没有 | 同第 2 步：板子已发出，PC 没显示 |
| RTT 没有 Received | 手机写入问题（Reliable Write / 0x16） |

---

## 第 5 步：Cursor 内置 COM6 终端

**操作：** 在 nRF Connect 侧边栏点 VCOM0 COM6

| 结果 | 说明 |
|------|------|
| 只显示 `Connected to COM6`，无数据 | **终端不显示 RX**，不代表 COM 坏了 |
| PuTTY 同步骤能收到 | 用 **PuTTY** 看 COM6，Cursor 只看 RTT |

---

## 快速对照表

| 现象 | 失败位置 |
|------|----------|
| RTT 无 `UART TX done` | 固件 / uart0 驱动 |
| RTT 有 TX done，PuTTY 无字 | J-Link VCOM 或打开顺序 |
| PuTTY 打字，RTT 无 `UART RX from COM` | COM6 发送 / 波特率 / 占端口 |
| RTT 有 Received，PuTTY 无 hello | 同第 2 步（TX 到 PC） |
| Cursor COM6 空，PuTTY 正常 | Cursor 终端显示问题 |

---

## 当前固件诊断 log 一览

| RTT 日志 | 含义 |
|----------|------|
| `Wait for DTR` / `DTR set` | 串口终端已连接 |
| `UART welcome queued` | 准备发欢迎语 |
| `UART TX done, N bytes` | 已从 uart0 发出 N 字节 |
| `UART RX from COM: ...` | PC 经 COM6 发来数据 |
| `Received N bytes ...: hello` | 手机经 BLE 发来 |
| `Failed to send data over BLE` | 手机 TX Notify 未开 |

改 `main.c` 或 `prj.conf` 后需重新编译烧录：

```powershell
cd e:\projects\business\summer\app_nus
west build -b nrf52840dk/nrf52840 -d build
west flash -d build --runner jlink
```
