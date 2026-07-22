# WalkEEG NUS 二进制帧协议

固件通过 Nordic UART Service (NUS) **TX Notify** 推送 8 通道电生理测试数据。  
设备广播名：**WalkEEG**  
NUS Service UUID：`6E400001-B5A3-F393-E0A9-E50E24DCCA9E`  
TX Characteristic：`6E400003-B5A3-F393-E0A9-E50E24DCCA9E`（Notify）

## 采样参数

| 项 | 值 |
|----|-----|
| 通道数 | 8 |
| 分辨率 | 16-bit signed (`int16`) |
| 采样率 | 2000 Hz |
| 端序 | **Little-endian** |
| 定时器 | 0.5 ms 产生 1 个时间点（8×i16） |

有效数据率：`8 × 16 bit × 2000 Hz = 256 kbps`（约 32 KB/s）

## 帧格式

| 偏移 | 字段 | 类型 | 说明 |
|------|------|------|------|
| 0 | `magic` | `u8` | 固定 `0xA5` |
| 1 | `version` | `u8` | 固定 `0x01` |
| 2 | `seq` | `u16 LE` | 帧序号，每帧 +1（溢出回绕） |
| 4 | `n_samples` | `u8` | 本帧时间点数 N |
| 5 | `flags` | `u8` | 预留，当前为 `0` |
| 6… | `payload` | `N × 8 × i16 LE` | 交错排列 |

**帧长** = `6 + N × 16` 字节。

**Payload 交错顺序**：

```
t0[ch0], t0[ch1], …, t0[ch7],
t1[ch0], t1[ch1], …, t1[ch7],
…
t(N-1)[ch0] … t(N-1)[ch7]
```

每个 `i16` 为 little-endian。

### 默认 N

- 默认 **N = 20** → 帧长 **326** 字节  
- 需要 ATT MTU ≥ 330（`MTU - 3 ≥ 326`）  
- 若协商 MTU 较小，固件按  
  `N = min(20, floor((mtu - 3 - 6) / 16))`  
  动态缩小（至少为 1）

## 测试信号算法

模拟斜坡（便于肉眼确认实时绘图与丢包）：

```
sec = 0..31          # 秒计数，到 32 回绕到 0
i   = 0..1999        # 本秒内样本索引（2 kHz）
base = sec * 1000 + i
sample[ch] = clamp(base + ch * 2000, 0, 32767)   # ch = 0..7
```

含义（与需求一致）：

- 第 1 秒：约 `0 → 1999`（CH0）；CH7 约 `14000 → 15999`
- 第 2 秒：约 `1000 → 2999`（CH0）
- …
- 第 32 秒：约 `31000 → 32767`（钳位）
- 然后回到第 1 秒

各通道相对基值偏移 `+ch×2000`，同屏叠加时曲线明显上下错开。

## 手机端解包要点

1. 连接后请求大 MTU（建议 512），订阅 NUS TX Notify  
2. Notify 可能粘包/半包：维护字节缓冲  
3. 找 `magic == 0xA5`，读 `n_samples`，计算 `frame_len = 6 + n_samples * 16`  
4. 缓冲够长则切出一帧；校验 `version == 0x01`  
5. 用 `seq` 检测丢包（允许 u16 回绕）  
6. 按交错顺序拆成 8 路环形缓冲后绘图；Y 轴范围建议 `0 … 32767`

## 伪代码（Dart / Flutter）

```dart
void feed(Uint8List chunk) {
  buf.addAll(chunk);
  while (true) {
    final start = buf.indexOf(0xA5);
    if (start < 0) { buf.clear(); return; }
    if (start > 0) buf.removeRange(0, start);
    if (buf.length < 6) return;
    final n = buf[4];
    final frameLen = 6 + n * 16;
    if (buf.length < frameLen) return;
    final frame = buf.sublist(0, frameLen);
    buf.removeRange(0, frameLen);
    parseFrame(frame); // seq @2 LE, samples from offset 6
  }
}
```

## 联调检查

1. nRF Connect：设备名 `WalkEEG`，TX Notify 为二进制（可见 `A5 01 …`）  
2. `seq` 连续递增  
3. Flutter 波形可见约 32 s 阶梯上升斜坡后回绕  
