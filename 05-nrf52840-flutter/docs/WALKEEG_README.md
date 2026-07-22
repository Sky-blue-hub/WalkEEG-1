# WalkEEG — 需求对照与交付说明

nRF52840 DK 经 BLE（NUS Notify）向手机推送 **8 通道 × 16-bit × 2 kHz** 测试斜坡；Flutter App 实时解包并绘制波形。

> 本阶段目标：**手机端能实时绘出透传数据**。真实心电/肌电/脑电 ADC、压缩上云、后端入库 **不在本阶段范围**。

---

## 需求对照

| 需求项 | 结论 | 说明 |
|--------|------|------|
| 8 通道电生理采样形态 | ✅ 满足（测试信号） | 固件按 8 路时间点生成；非真实 ADC |
| 分辨率 16-bit（已取消 24-bit） | ✅ 满足 | `int16` LE，范围 0…32767（斜坡钳位） |
| 采样率 2 kHz | ✅ 满足 | 0.5 ms 定时器，每拍 8×i16 |
| 数据量约 256 kbps | ✅ 满足 | `8 × 16 × 2000 = 256 kbps`（≈32 KB/s） |
| BLE：NUS / Notify / 大 MTU | ✅ 满足 | NUS TX Notify；App `requestMtu(512)`；固件 L2CAP MTU 498 |
| BLE：短连接间隔 / 2M PHY | ✅ 满足 | Pref interval 7.5–15 ms；请求 2M PHY |
| 帧协议可被 Flutter/iOS 解包 | ✅ 满足 | 见 [WALKEEG_PACKET.md](WALKEEG_PACKET.md) |
| 测试斜坡（秒级递增、32 s 回绕） | ✅ 满足 | `base = sec×1000 + i`；通道 `+ch×2000` 便于区分 |
| Flutter 实时绘图 | ✅ 满足 | `mobile_walkeeg/`：最多 4 路同屏、Y 轴、`seq/drops/loss%` |
| nRF 压缩 + 手机解压 | ❌ 未做 | 可选后续优化 |
| 后端 S3 / IoT / API Gateway | ❌ 未做 | 明确为后续阶段 |
| 真实 24-bit / 真实传感器 | ❌ 不做 / 未做 | 需求已改为 16-bit 测试信号 |

**阶段结论：当前交付满足「透传 + 实时绘波形」验收目标。**

---

## 系统架构

```
nRF52840 DK (app_nus)
  0.5 ms 定时器 → 8×i16 斜坡样本
       ↓
  组帧 (magic/ver/seq/N/payload)
       ↓
  NUS TX Notify  ──BLE 5 / 2M──►  手机 Flutter App
                                      粘包缓冲 + 解帧
                                      8 路环形缓冲
                                      实时波形 + 丢包统计
```

| 组件 | 路径 |
|------|------|
| 固件（NUS + 推流） | [`app_nus/`](../app_nus/) |
| 推流核心 | [`app_nus/src/stream.c`](../app_nus/src/stream.c) |
| Flutter App | [`mobile_walkeeg/`](../mobile_walkeeg/) |
| 帧协议 | [WALKEEG_PACKET.md](WALKEEG_PACKET.md) |
| 联调清单 | [WALKEEG_VERIFY.md](WALKEEG_VERIFY.md) |
| 离线自检 | [`tools/walkeeg_protocol_selfcheck.py`](../tools/walkeeg_protocol_selfcheck.py)、[`tools/walkeeg_e2e_sim.py`](../tools/walkeeg_e2e_sim.py) |

---

## 采样与数据量（定稿）

| 项 | 值 |
|----|----|
| 通道数 | 8 |
| 分辨率 | 16-bit |
| 采样率 | 2000 Hz |
| 有效比特率 | **256 kbps**（≈ 32 KB/s） |
| 一小时原始量 | ≈ **113 MB** |

> 文案里曾出现「16-bit 却按 24-bit 算 288 kbps」的笔误；以 **16×8×2000 = 256 kbps** 为准。早期 24-bit / 384 kbps 方案已废弃。

---

## 测试信号

```
sec = 0..31,  i = 0..1999
base = sec * 1000 + i
sample[ch] = clamp(base + ch * 2000, 0, 32767)
```

- 第 1 秒 CH0：约 `0 → 1999`
- 第 2 秒 CH0：约 `1000 → 2999`
- …
- 第 32 秒：高位钳位到 32767，然后回绕
- `ch×2000`：同屏多通道时曲线上下错开（纯 `+ch` 在全量程下几乎看不见）

---

## 透传帧结构（解包依据）

比早期「1B 通道号 + payload + 2B seq」更适合高吞吐：**一帧携带 N 个时间点的全部 8 通道**，seq 在帧头。

| 偏移 | 字段 | 类型 | 说明 |
|------|------|------|------|
| 0 | magic | u8 | `0xA5` |
| 1 | version | u8 | `0x01` |
| 2 | seq | u16 LE | 帧序号 |
| 4 | n_samples | u8 | 本帧时间点数 N |
| 5 | flags | u8 | 预留 `0` |
| 6… | payload | N×8×i16 LE | 按时间交错：t0 全通道 → t1 全通道 → … |

- 默认 **N = 20** → 帧长 **326** 字节 → 需要 ATT MTU ≥ 330  
- 广播名：**WalkEEG**  
- 完整字段与伪代码：[WALKEEG_PACKET.md](WALKEEG_PACKET.md)

---

## 快速跑通

### 固件

```powershell
cd app_nus
west build -b nrf52840dk/nrf52840 -d build_walkeeg
west flash -d build_walkeeg
```

### Flutter（建议国内镜像）

```powershell
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
cd mobile_walkeeg
flutter pub get
flutter test
flutter run
```

App：点蓝牙扫描 → 连接 **WalkEEG** → 看斜坡；状态行关注 `seq` / `drops` / `loss%`。

### 无板子自检

```powershell
python tools/walkeeg_protocol_selfcheck.py
python tools/walkeeg_e2e_sim.py
```

更细步骤见 [WALKEEG_VERIFY.md](WALKEEG_VERIFY.md)。

---

## 验收标准（本阶段）

1. 手机能扫到并连接 **WalkEEG**
2. 连接并开 Notify 后出现连续斜坡，约 **32 s** 回绕
3. `seq` 连续上涨，`drops` / `loss%` 在良好环境下接近 0
4. 切换或同屏多选 CH0–CH7，能看到通道高度差（`×2000` 偏移）
5. `flutter test` 与 Python 协议自检通过

---

## 后续（非本阶段）

- 真实 ADS/前端 ADC → 替换测试斜坡
- 可选压缩（降 BLE/上云压力）
- 手机 → 云（S3 / IoT Core 或 API Gateway → Lambda → DynamoDB/S3）
- iOS 真机专项验证与上架相关配置
