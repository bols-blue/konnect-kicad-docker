# CM キャリアボード(LTE / Ethernet / USB ハブ / micro HDMI) 要件・部品選定

ステータス: **承認済み** — 2026-09-29(外形制約なし → CM 標準 55×40 mm の取付パターンから開始)

## 1. 目的

Raspberry Pi Compute Module を載せるドーターボード。LTE、Gigabit Ethernet、USB ハブ、
micro HDMI 映像出力を持つ。

## 2. 決定済み要件

| 項目 | 内容 |
| --- | --- |
| 対応モジュール | **CM4 Lite / CM5 Lite 両対応**(ピン互換の範囲で設計) |
| ストレージ | **microSD スロット**(Lite のため)。eMMC 書き込み経路(rpiboot)は **持たない** |
| 電源入力 | 外部 5V 電源ボードから **JST XA** で受電(基板上に一次側 DC-DC は持たない) |
| 外部 USB | 3 ポート = **USB Type-C ×1 + XA ハーネス ×2**(すべて USB 2.0 ホスト) |
| LTE | **Quectel EC25-J(Mini PCIe)**。内部 USB 接続(ハブの 1 ポートを使用) |
| Ethernet | 1000BASE-T ×1(モジュール内蔵 PHY + トランス内蔵 RJ45) |
| 映像 | micro HDMI(Type D)×1、HDMI0 を使用 |

## 3. 両対応の設計方針(根拠: CM5 datasheet RP-008180-DS 付録 B / ピン表)

- **USB は CM4/CM5 共通の USB 2.0 ピン(103 = USB_N, 105 = USB_P)だけを使い、USB ハブで分岐する。**
  CM5 の USB 3.0 ポートは CM4 の CAM0(128–142)/ DSI0(157–171)に割り当てられているため、
  両対応にすると使えない。CM5 では `dtoverlay=dwc2,dr_mode=host` が必要(datasheet 2.4.2)。
- USB_OTG_ID(101)は GND に落としてホスト固定(datasheet: "For fixed-role use, tie the USB_OTG_ID pin to ground")。
- ピン 111 は CM4 では VDAC_COMP、CM5 では VBUS_EN(USB3 用)→ **未接続**。
- ピン 94 / 96 は CM4 では ADC、CM5 では USB-C PD の CC → **未接続**(XA で受電するため)。
- CM5 は HDMI / SDA / SCL / HPD / CEC の ESD 保護がモジュールから削除されている → **キャリア側で ESD 保護必須**。
- HDMI の HPD / SDA / SCL / CEC は 5V トレラントで直結可(CM5 ピン表)→ レベル変換 IC は不要。

## 4. 部品候補

| ブロック | 候補 | 根拠 | 確度 |
| --- | --- | --- | --- |
| CM コネクタ | Hirose DF40C-100DS-0.4V(51) ×2(1.5mm スタック)/ DF40HC(3.0)-100DS-0.4V(51)(3mm) | CM4/CM5 データシートの推奨品 | 高(末尾型番は要確認) |
| USB ハブ | Microchip USB2514B(4 ポート USB 2.0) | 公式 CM4 IO Board で採用。ポート割当: LTE / Type-C / XA-1 / XA-2 | 高 |
| ハブ用水晶 | 24 MHz | USB2514B のデータシート要求 | 高 |
| ポート電源 | 電流制限付きハイサイドスイッチ ×3 | 下流ポートの短絡保護。型番は電流仕様の決定後 | 中 |
| USB ESD | USBLC6-2SC6 ×3 | USB 2.0 ESD の定番 | 中 |
| Type-C(ホスト) | USB 2.0 レセプタクル + CC1/CC2 に Rp = 56 kΩ(→5V) | Type-C 仕様の Default USB Power 用 Rp。VBUS を常時出しっぱなしにするのは仕様違反になるので CC 検出 IC の追加を検討 | 中 |
| USB 用 XA | 4 ピン(VBUS / D− / D+ / GND) | D+/D− はツイストペアの短いハーネス前提。コネクタ部はインピーダンス非制御 | 中 |
| 電源用 XA | 8 ピン(5V ×4 / GND ×4)。例: B08B-XASK-1 | §6 の計算 | 中(型番は要確認) |
| Ethernet | 1000BASE-T 対応のトランス内蔵 RJ45(LED 付き) | PHY はモジュール内蔵。型番は CT 接続の要求を確認して確定 | 中 |
| micro HDMI | Type D レセプタクル + TMDS 用 ESD アレイ + HDMI 5V 用ロードスイッチ(または TPD12S016 系) | CM5 は ESD 保護を削除済み | 中 |
| LTE | Quectel EC25-J Mini PCIe + Mini PCIe ソケット + SIM ソケット + 3.3V 専用 DC-DC | §5 | 中(電源電流は要確認) |
| microSD | Push-push microSD ソケット + SD 電源用ロードスイッチ(SD_PWR_ON(75)で制御、プルアップで既定 ON) | CM5 datasheet 2.7「SD cards require a power switch controlled by SD_PWR_ON」。SD_VDD_OVERRIDE(73)は未接続(3.3V 信号の SD カード) | 高 |

## 5. LTE モジュール比較

| | EC25-J(Mini PCIe) | EG25-G(Mini PCIe) | EC25-J(LGA 直実装) |
| --- | --- | --- | --- |
| カテゴリ | LTE Cat.4 | LTE Cat.4(グローバル) | LTE Cat.4 |
| 国内認証 | TELEC (R) 018-190011 / JATE ADF18-0088018(Quectel フォーラムで確認) | 技適の書類は Quectel に個別請求(未確認) | Mini PCIe 版とは別の認証になる可能性あり(要確認) |
| キャリア認定 | docomo / SoftBank(Quectel の記載) | 要確認 | 同左 |
| Linux | mainline の option / qmi_wwan で動作 | 同左(PinePhone でも採用) | 同左 |
| 基板側の設計負担 | 小: ソケット + SIM + 3.3V 電源 + USB | 小 | 大: RF 線路、アンテナ整合、電源設計を自前で行う |
| アンテナ | U.FL(IPEX)で外付け | 同左 | 基板上の RF 設計 |
| **評価** | **採用** | 予備 | 量産時の検討候補 |

注意: 技適は「モジュール + 使用するアンテナ」の組み合わせで取得されている。認証で使われた
アンテナの型番を Quectel / 代理店に問い合わせて確認すること。

## 6. 電源(5V)の見積もり

| 負荷 | 5V 側の電流 | 根拠 |
| --- | --- | --- |
| CM5(CM4 はこれより小さい) | 2.5 A | CM5 datasheet 付録 B.3「5 V at up to 2.5 A」 |
| 外部 USB ×3 | 1.5 A | USB 2.0 の既定値 500 mA × 3 |
| LTE | 約 1.5 A | 3.3 V × 2 A(ピーク、**未確認**)÷ 5 V ÷ 効率 0.9 |
| ハブ / HDMI 5V / その他 | 約 0.25 A | HDMI 5V は 55 mA |
| **合計(ピーク)** | **約 5.7 A** | |

- XA の端子 SXA-001T-P0.6 の定格は 3 A、電線は AWG 22〜28。
- 複数極を同時に通電するので、1 極あたり 2 A に減定格して計算: 5.7 A ÷ 2 A ≈ 2.9 → 最低 3 極。
  **5V 4 極 + GND 4 極 の 8 ピン**で余裕を持たせる。
- 電圧降下(AWG22 = 約 53 mΩ/m、30 cm、4 本並列): 往復で約 45 mV。

## 7. KiCad 10 標準ライブラリの有無(konnect-kicad:10 イメージで確認)

| 部品 | シンボル | フットプリント | 対応 |
| --- | --- | --- | --- |
| CM4/CM5 本体 | 標準には無し → **公式 IO Board の KiCad データに `ComputeModule5-CM5` / `ComputeModule4-CM4` あり** | 公式データに `Raspberry-Pi-5-Compute-Module` / `-4-` あり(2 コネクタ一体、204 パッド) | 公式データを流用(§7.1) |
| USB2514B | `USB2514B_Bi` | (QFN36、標準品) | 流用 |
| Mini PCIe ソケット | `Bus_PCI_Express_Mini` | `Connector_PCBEdge:BUS_PCI_Express_Mini_Full`(基板側ソケット、PCIe Mini CEM 仕様準拠の汎用品。SMD 54 + 位置決め穴 2) | 流用。**採用するソケットのデータシートとパッド寸法を照合すること** |
| SIM | `SIM_Card` 系 | nanoSIM(GCT SIM8060 / CUI NSIM-2-C)、JAE SF72S006 | 流用 |
| micro HDMI | 汎用 HDMI シンボル(Type D 専用は無し) | Molex 46765-1xxx / 2xxx | 流用(ピン割り当ては要確認) |
| HDMI ESD | `TPD4EUSB30`(標準・公式データの両方にあり)。TPD12S016 は無し | 標準品 | **公式 CM4/CM5 IO Board と同じ TPD4EUSB30 ×3 に変更** |
| RJ45 | 公式データに `MagJack-A70-112-331N126` | 公式データに `TRJG0926HENL` | 公式 IO Board と同じ MagJack を流用 |
| JST XA | (汎用 Conn_01x08) | B08B-XASK-1、B04B 系 | 流用 |
| microSD | `Micro_SD_Card_Det*` | Hirose DM3、Molex 104031 ほか | 流用 |
| Type-C(USB 2.0) | `USB_C_Receptacle_USB2.0_16P` | 標準品 | 流用 |
| Type-C 接続検出 | `TUSB320` | 標準品 | 採用候補 |
| USB ESD / ポート電源 | `USBLC6-2SC6` / `TPS2051CDBV` | 標準品 | 流用 |

### 7.1 ダウンロード元(2026-09-29 に取得・中身確認済み)

| データ | URL | 形式 | ライセンス |
| --- | --- | --- | --- |
| CM5 IO Board rev2 KiCad | https://pip.raspberrypi.com/categories/1098-design-files | KiCad 9(README に記載) | 明記なし(3D モデルは各メーカーの規約に従う) |
| CM4 IO Board KiCad | https://pip.raspberrypi.com/categories/1210-design-files | KiCad 6 | 同上 |
| (参考)Mini PCIe コミュニティ版 | https://github.com/mithro/kicad-mini-pci-express | KiCad 4(2018) | Apache-2.0 → 標準品があるので不採用 |

- CM4 と CM5 のフットプリントは、パッド数(204)と Y 座標が同じで、X 座標だけ ±0.04 mm 違う
  (CM5 はコネクタのメーカーが変わったため)。**CM5 のものを採用**する。
- CM4 と CM5 のシンボルは、ピン番号は同じで、ピン名が 48 本違う(16/19/76/92/94/96/99/100/102/104/106/111 と、
  カメラ / DSI / USB3 のピン群)。**CM5 のシンボルを採用し、違いのあるピンは本設計では使わない**
  (§3 の方針と一致)。
- USB2514B ハブと FSUSB42 まわりの参考回路は、公式 CM4 IO Board の `USB2-HUB.kicad_sch` にある。
- ライセンスが明記されていないので、評価以外に使う前に Raspberry Pi に確認すること。

## 8. 未決事項

- [x] LTE モジュール → EC25-J Mini PCIe
- [x] ストレージ → Lite 版 + microSD、rpiboot 経路なし
- [ ] EC25-J の認証で使われたアンテナ型番(Quectel / 代理店に問い合わせ)
- [ ] CM5 で PD ネゴシエーションが無いときの USB 電流制限の扱い(EEPROM 設定で済むか)
- [ ] LTE の 3.3V 電源の電流値(Quectel の Mini PCIe 版 HW 設計ガイド)
- [ ] 基板外形・取付穴・部品高さの制約
