# Mesh 组网（NUS 跑通之后）

## 前置条件

- NUS 蓝牙串口已在 nRF52840 DK 上跑通
- 下载 Mesh 网盘资料（提取码 `dpv7`）
- **至少 2 块 nRF52840 开发板**（DK 或其他 nRF52840 板）

## NCS 自带 Mesh 样本

SDK 安装后，样本位于：

```
C:\ncs\vX.Y.Z\nrf\samples\bluetooth\mesh\
```

推荐入门样本：

| 样本 | 说明 |
|------|------|
| `mesh/onoff_level_lighting` | 开关 + 亮度 Mesh 灯控 |
| `mesh/sensor_server` | Mesh 传感器服务端 |
| `mesh/light_switch` | 轻量级开关 |

## 编译示例（单节点）

在 **nRF Connect Terminal** 中：

```powershell
cd C:\ncs\vX.Y.Z\nrf\samples\bluetooth\mesh\onoff_level_lighting
west build -b nrf52840dk/nrf52840 -d build
west flash -d build
```

对第二块板重复烧录（可改 `CONFIG_BT_MESH_SUBNET_COUNT` 等配置）。

## 手机测试

- 使用 **nRF Mesh** app（Nordic 官方，不是 nRF Connect）
- 或按网盘资料中的工具/流程操作

## 学习资料

- [NCS Bluetooth Mesh 文档](https://docs.nordicsemi.com/bundle/ncs-latest/page/nrf/protocols/bt/mesh/index.html)
- 老板提供的 Mesh 网盘资料（提取码 dpv7）

## 与 NUS 的区别

| | NUS | Mesh |
|---|-----|------|
| 连接方式 | 1 对 1 蓝牙连接 | 多节点网状网络 |
| 协议层 | GATT Service | Mesh 模型 (Models) |
| 手机 app | nRF Connect | nRF Mesh |
| 板子数量 | 1 块即可 | 通常需要 2+ 块 |
