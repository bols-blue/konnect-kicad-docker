# route-test 仕様

目的: 回路図 → PCB 反映 → フットプリント配置 → DSN 出力 → Freerouting →
SES 取り込み → DRC を実基板で一通り通す検証。回路の機能は二の次で、
配線が発生する最小構成にする。

## 回路

抵抗分圧器 (Vout = Vin × R2 / (R1 + R2))。

| Ref | 部品 | 値 | フットプリント | 根拠 |
| --- | --- | --- | --- | --- |
| J1 | Conn_01x03 | — | Connector_PinHeader_2.54mm:PinHeader_1x03_P2.54mm_Vertical | VIN / VOUT / GND を外に出す |
| R1 | R | 10k | Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal | R1 = R2 で Vout = Vin/2。電流 = Vin/20kΩ (5V で 0.25 mA)、損失 = 5²/20k = 1.25 mW。DIN0207 型の一般的な定格 0.25 W に対し十分余裕 (型番未選定のため定格は要確認) |
| R2 | R | 10k | Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal | 同上 |

ネット: VIN (J1.1–R1.1)、VOUT (J1.2–R1.2–R2.1)、GND (J1.3–R2.2)

## 基板

- 2 層、外形 30 × 20 mm
- 製造先は想定しない (KiCad の既定デザインルールで DRC)
- 電源電圧・電流は検証用のため規定しない (上記は 5V 入力を仮定した場合の計算)

## 改訂履歴

- 当初は R_0805_2012Metric (SMD)。Konnect 0.12.1 の DSN 出力が roundrect パッドを
  受け付けない (circle / rect のみ) ため、Konnect 単独で自動配線を通す検証用に
  THT (パッドが circle のみ) に変更。SMD 版は route-test-smd で GUI 併用手順を検証する
