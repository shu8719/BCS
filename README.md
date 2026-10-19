# BCS — Business Card Scanner

iPhone で名刺を撮るだけで、氏名・会社・電話・メール・住所を読み取り、米国の時間帯（PST / MST / CST / EST）と相手の現地時刻まで表示する iOS アプリです。読み取り結果は CSV で書き出して Excel で管理できます。

- **言語 / UI**: Swift 5 / SwiftUI（iOS 17+）
- **OCR**: Vision（`VNRecognizeTextRequest`）+ VisionKit の書類カメラ
- **デザイン**: Material 3 ベース。Figma で設計し、Figma MCP 経由でトークンとアイコンを取り込み
- **テスト**: XCTest 105 件 + 実名刺の OCR 結果を使った精度評価

---

## 背景

もらった名刺が増えすぎて管理できない、営業先が米国の 4 つの時間帯にまたがっていて電話のタイミングを毎回調べている、という 2 つの困りごとが出発点です。

- 名刺は撮るだけ。項目分けはアプリが行い、人は確認するだけ
- 住所の郵便番号（または電話の市外局番）から時間帯を自動判定し、一覧に **相手の現地時刻** を出す
- データは端末内だけで完結（サーバーなし、画像も保存しない）

---

## 画面

> 画像は Figma の設計データです。実機のスクリーンショットに順次差し替えます。

| 一覧 | スキャンメニュー | 複数選択 |
|:--:|:--:|:--:|
| <img src="docs/screens/01_list.png" width="230"> | <img src="docs/screens/01b_scan_menu.png" width="230"> | <img src="docs/screens/02_select.png" width="230"> |
| 検索・要確認 / 時間帯の絞り込み、今週 / それ以前のグループ、現地時刻 | FAB が閉じるボタンに変形し、「写真から選ぶ」「カメラでスキャン」が展開 | 長押しで選択モード。選んだ名刺を CSV 書き出し / 削除 |

| 詳細 | 編集 | 読み取り結果 | 設定 |
|:--:|:--:|:--:|:--:|
| <img src="docs/screens/03_detail.png" width="180"> | <img src="docs/screens/04_edit.png" width="180"> | <img src="docs/screens/06_scan_result.png" width="180"> | <img src="docs/screens/07_settings.png" width="180"> |
| 要確認バナー、電話 / メール / 地図へのクイックアクション、読み取り元の表示 | Outlined フィールドと自動判定したタイムゾーンの根拠 | スキャン直後の確認画面。保存するまで永続化しない | 言語切替、CSV 一括出力、全削除 |

---

## 主な機能

| 機能 | 概要 |
|------|------|
| 名刺スキャン | 書類カメラ、または写真ライブラリの画像 → Vision OCR → 独自パーサーで項目分け |
| 要確認フラグ | 書式を補正した電話番号、読み取れなかった名前・会社、郵便番号と市外局番で時間帯が食い違う名刺に「要確認」を付け、一覧・詳細・結果画面で一貫して表示。読み取り元の文字列も保持 |
| タイムゾーン推定 | 米国住所の郵便番号（優先）/ 市外局番から PST・MST・CST・EST を判定。一覧と詳細に現地時刻と日本との時差 |
| 一覧 | 名前・会社・メール検索、要確認 / 時間帯の絞り込み、並び替え、今週 / それ以前のグループ |
| 詳細 / 編集 | `tel:` `mailto:` 地図へのクイックアクション、項目コピー、編集で変更した項目の要確認は自動解除 |
| CSV 出力 | RFC 4180 / UTF-8 BOM / CRLF（Excel・Numbers 対応）。`needs_review` と `raw_value` 列付き |
| 日英対応 | 端末に合わせる / 日本語 / English を設定で切替 |
| 削除 Undo | 単体・複数・全削除を 6 秒以内なら復元 |

---

## 技術的なポイント

### 1. OCR 後の多段パーサー

Vision が返すのは座標付きのテキスト断片です。`CardParser` が次の順で名刺に組み立てます。

```
OCR 断片
  → 行の再構築      Y 座標でグループ化し、列の隙間（文字高さの 1.5 倍超）で 2 列レイアウトを分割
  → AddressParser    住所らしい行を起点にブロックを成長・結合・採点し、最良ブロックを整形
  → PhoneParser      正規表現 + NSDataDetector で番号を二重取得、ラベル（直通 / 代表 / 携帯）付与、FAX 除外
  → NameParser       文字高さ・位置・TitleCase・メールアドレスとの一致をスコアリングして人名を選定
  → ReviewFlagger    米国番号を +1 NXX-NXX-XXXX に整形し、要確認を付与
```

キーワード判定は単語境界付きで、"Weber" が "web" に、"Repton" が "rep" に誤反応しないようにしています。

### 2. 実名刺で測る精度評価

パーサーは経験則の塊なので、改修で壊していないことを数字で確認できる仕組みを用意しました。

1. DEBUG ビルドの設定画面から、直近のスキャンの **OCR 結果（テキストと座標）** をフィクスチャ JSON として書き出す（画像は含めない）
2. `BCSTests/Fixtures/` に置き、期待値の誤りだけ手で直す
3. `FixtureAccuracyTests` が全フィクスチャをパーサーに流し、項目別の正解率を出す

```
Fixture accuracy (20 fixtures)
  name      17/20   85.0%
  company   15/20   75.0%
  ...
Failures:
  [paper_acme_20261016] name: expected "John Smith" / actual "Sales Manager"
```

### 3. タイムゾーン判定の落とし穴

`TimeZone.abbreviation` は端末のロケールに依存し、日本語設定の iPhone では "EDT" ではなく "GMT-4" を返します。これで判定が全部空になる不具合を踏んだため、IANA 識別子の **標準時オフセット** から PST / MST / CST / EST を決める実装に変えました。郵便番号は「州コードの直後の 5 桁」を優先し、番地（10300 など）を郵便番号と誤認しないようにしています。

### 4. 壊れない永続化

保存形式は JSON です。項目を `ContactField`（値・読み取り元・要確認理由）に拡張した際も、旧形式のファイルをそのまま読める互換デコーダを用意し、読めないファイルは上書きせず退避します。

---

## アーキテクチャ

```
BCSApp
└── RootView (TabView)
    ├── CardListView         # 一覧 / 複数選択（検索・絞り込み・週グループ・FAB メニュー）
    │   ├── CardDetailView   # 詳細（要確認バナー・クイックアクション）
    │   │   └── CardEditView # 編集シート
    │   └── ScanFlow         # FAB → ScannerView / 写真 → ScanResultView → CardStore.append
    └── SettingsView         # 設定（DEBUG ビルドでは開発用ツールも表示）

OCR         TextRecognizer（Vision）
Parsing     CardParser → AddressParser / PhoneParser / NameParser / ReviewFlagger
Model       BusinessCard（ContactField）、CardStore（永続化・複数削除・Undo）
TimeZone    TimeZoneResolver（ZIP / 市外局番 → TimeZoneResolution）、TimeZoneLookupTable（CSV）
DesignSystem M3 / BCSTextStyle / BCSIcon / Components
```

表示ロジック（検索・絞り込み・グループ分け・現地時刻・文言生成）は View から切り出し、ユニットテストで固定しています。

---

## ファイル構成

```
BCS/
├── App/            BCSApp, RootView
├── DesignSystem/   M3Color, BCSTextStyle, BCSIcon, Components/
├── Views/          CardList/, CardDetail/, CardEdit/, Scan/, Settings/, ScannerView, ShareSheet
├── OCR/            TextRecognizer, OCRTypes
├── Parsing/        CardParser, AddressParser, PhoneParser, NameParser, PhoneNormalizer, ReviewFlagger, ParserUtils
├── Model/          BusinessCard, CardStore, AppSettings
├── TimeZone/       TimeZoneResolver, TimeZoneLookupTable, uszips.csv, ac-tz.csv
├── Support/        L10n, CSVExporter, CardListFilter, LocalTime
├── DevTools/       CardFixture, FixtureRecorder（DEBUG のみ）
└── Assets.xcassets M3/（Color Set）, Icons/（SVG）
BCSTests/
├── Fixtures/       実名刺の OCR 結果 + 期待値
└── *Tests.swift    パーサー・モデル・ストア・一覧ロジック・文言・スキャン導線
docs/
├── screens/        画面画像
└── superpowers/    設計書と実装計画
```

---

## セットアップ

```bash
git clone https://github.com/shu8719/BCS.git
cd BCS
open BCS.xcodeproj
```

Xcode 16 以降でスキーム `BCS` を選び、実機でビルドしてください（カメラを使うため）。テストは Cmd+U で実行できます。

---

## 今後の改善案

- [ ] 日本語名刺対応（OCR 言語設定と日本語向けパーサー）
- [ ] カスタムカメラ（ガイド枠・自動撮影・検出チップ）
- [ ] SwiftData + iCloud 同期
