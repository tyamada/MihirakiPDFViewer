# MihirakiPDFViewer

右綴じの本（日本語の書籍など）の表示に適した、シンプルで直感的に
使えるPDFビューアです。

PDFを開くと、ページレイアウトとスクロール方向の設定を検出します。
PDFを単ページ表示または見開き表示で表示します。

このソフトウェアは生成AIを使用してコーディングしました。

## 機能

- **PDF文書の表示**: PDFファイルをスムーズに開いて閲覧できます。
- **ズーム**: 読みやすさを高める直感的なズーム操作に対応しています。
- **検索**: PDF文書内のテキストをすばやく検索できます。
- **レイアウトオプション**: 単ページ表示と見開き表示を切り替えられます。

## 使い方

1. **PDFを開く**: ファイルピッカーを使って、端末またはiCloud Drive
   からPDFファイルを選択します。
2. **ページ移動**: スワイプまたはスライダーを使ってページを切り替え
   ます。
3. **メニュー**: 画面をタップして、ツールバーとスライダーの表示/非表示
   を切り替えます。
4. **ズーム**: ピンチ操作で拡大または縮小します。拡大中は長押しして
   からドラッグするとスクロールできます。
5. **検索**: 検索バーにテキストを入力して、PDF内の特定の内容を検索
   します。
6. **レイアウト**: メニュー内のレイアウトオプションを使って、単ページ
   表示と見開き表示を切り替えます。

## オプション

### 表紙設定

- **Type A**（Adobe Acrobat Reader互換）
  `PageLayout`が`TwoPageRight`または`TwoColumnRight`の場合は表紙あり、
  それ以外の場合は表紙なしとして扱います。
- **Type B**
  `Direction`が`L2R`で、`PageLayout`が`TwoPageRight`または
  `TwoColumnRight`の場合は表紙ありとして扱います。
  `Direction`が`R2L`で、`PageLayout`が`TwoPageLeft`または
  `TwoColumnLeft`の場合は表紙ありとして扱います。
  それ以外の場合は表紙なしとして扱います。

## インストール（ソース）

### 前提条件

- macOS 26.6
- Xcode 26.6

### Xcodeでのビルド手順

#### 1. 新規プロジェクトを作成する

1. **Xcode**を起動します。
2. **"Create a new Xcode project..."**を選択し、**"Next..."**を
   クリックします。
3. プラットフォームに**"iOS"**、アプリケーション種別に**"App"**を
   選択し、**"Next..."**をクリックします。
4. プロジェクト設定を入力します。
   - **Product Name**: `MihirakiPDFViewer`（任意）
   - **Organization Identifier**: `com.yourname`（任意）
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - **Storage**: `None`（デフォルト）
5. 保存先を選択し、**"Create"**をクリックします。

#### 2. ソースファイルを取り込む

1. GitHubからソースコードをダウンロードします。
2. `Sources`フォルダ内にあるフォルダ（`App`、`Managers`、`Models`、
   `ViewModels`、`Views`）を、Xcode左側の**Project Navigator**
   （ファイルツリー）へ**ドラッグ&ドロップ**します。
3. 表示されるダイアログ（Add to "MihirakiPDFViewer"）で、以下の
   ように設定します。
   - **Destination**: `Create groups`を選択します
     （*重要: フォルダ構成を維持するため*）
   - **Options**: `Copy items if needed`にチェックを入れます

#### 3. エントリポイント（Appファイル）を変更する

デフォルトでは、Xcodeは自動生成されたファイルを使ってプロジェクトを
起動するように設定されています。提供されたコードを使うように更新する
必要があります。

1. XcodeのProject Navigatorで、自動生成された`[Project Name]App.swift`
   ファイルを削除します。
2. `Sources/App/MihirakiPDFViewerApp.swift`がプロジェクトに含まれている
   ことを確認します。

#### 4. ビルドして実行する

1. XcodeツールバーのRunボタン（**▶️**）右側にあるデバイス選択メニュー
   をクリックし、**iPadシミュレータ**（例: "iPad Pro"）を選択します。
2. **▶️（Run）**ボタンをクリックするか、キーボードで`Command + R`を
   押します。
3. シミュレータが起動し、PDFファイルを選択する画面が表示されれば、
   セットアップは成功です。

### トラブルシューティング

- **エラーが発生する場合**: `import PDFKit`でエラーが出る場合は、
  プロジェクトの**Frameworks, Libraries, and Embedded Content**に
  `PDFKit`が含まれているか確認してください（通常はデフォルトで含まれ
  ています）。
- **"File not found"エラー**: XcodeのProject Navigatorでファイルが赤く
  表示される場合、ファイルパスが正しくリンクされていません。その
  ファイルを削除し、もう一度ドラッグ&ドロップで追加してください。

## AIの主な役割

- 初期コードの自動生成（Cline & gemma-4-26b-a4b-qat）
- デバッグ提案（Cline & gemma-4-26b-a4b-qat）
- コード変更とバグ修正（Xcode & Codex）
- アプリアイコンとチップ画像の作成（ChatGPT）

## 参考資料

1. [Demystifying PDF Page Display Settings](https://qiita.com/TETSURO1999/items/e7a69026bdf8b5e8c631)

## ライセンス

このプロジェクトはMIT Licenseの下でライセンスされています。詳細は
[LICENSE](LICENSE)ファイルを参照してください。

## バージョン履歴

- **v0.1.0** - 2026/08/16: 初回リリース。
- **v0.2.0** - 2026/08/19: 投げ銭機能を追加。
- **v0.2.1** - 2026/08/20: README.mdを日本語版へ変更。
- **v0.2.2** - 2026/08/21: 自動テストを追加。
- **v0.3.0** - 2026/08/26: UIを更新し、ズーム中のドラッグ操作を追加。
  表紙サイズの調整も修正。
