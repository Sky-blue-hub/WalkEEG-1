# WalkEEG 联调清单

## 固件

1. 编译（nRF Connect Terminal 或已配置 west 的 shell）：

```powershell
cd e:\projects\business\summer\app_nus
west build -b nrf52840dk/nrf52840 -d build_walkeeg
```

2. 烧录：

```powershell
west flash -d build_walkeeg
```

产物：`app_nus/build_walkeeg/merged_nrf52840dk_nrf52840.hex`

3. 设备广播名应为 **WalkEEG**
4. RTT 应看到 `WalkEEG stream module ready`
5. 手机/nRF Connect 连接后启用 NUS TX Notify
6. RTT：`NUS TX notify enabled` → `WalkEEG stream started`
7. Notify 首字节应为 `A5 01 …`（二进制，不是 ASCII）

## 协议自检（无板子）

```bash
python tools/walkeeg_protocol_selfcheck.py
python tools/walkeeg_e2e_sim.py
```

应分别输出 `OK: WalkEEG packet + ramp self-check passed` 与 `OK: e2e stream/parser simulation passed`。

## Flutter

```bash
cd mobile_walkeeg
flutter create . --project-name mobile_walkeeg   # 补齐平台脚手架（首次）
flutter pub get
flutter test
flutter run
```

App 内确认：

- `seq` 连续递增（`drops` 接近 0）
- 波形为阶梯斜坡，约 32 s 回绕
- 切换 CH0–CH7 可见通道偏移

## 丢包时排查

- 确认 MTU ≥ 330（App 已 `requestMtu(512)`）
- 靠近板子，减少 2.4 GHz 干扰
- 看 RTT 是否有 `bt_nus_send err`
