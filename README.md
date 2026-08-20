# MihirakiPDFViewer

右綴じの書籍（日本語の書籍など）の表示に適した、シンプルで直感的なPDFビューアです。

PDFを開くと、ページレイアウトとスクロール方向の設定を検出します。PDFは単一ページ表示または見開き表示で閲覧できます。

このソフトウェアは生成AIを使用してコーディングされました。

## 機能

- **PDFドキュメントの表示**: PDFファイルをスムーズに開いて閲覧できます。
- **検索**: PDFドキュメント内のテキストをすばやく検索できます。
- **レイアウトオプション**: 単一ページ表示と見開き表示を切り替えられます。
- **設定**: 閲覧体験をカスタマイズできます。
- **ズーム**: 直感的なズームジェスチャーで読みやすく表示できます。

## 使い方

1. **PDFを開く**: ファイルピッカーを使って、端末またはiCloud DriveからPDFファイルを選択します。
2. **ページ移動**: スワイプまたはスライダーでドキュメント内を移動します。
3. **検索**: 検索バーに入力して、PDF内の特定のテキストを検索します。
4. **ズーム**: ピンチ操作で表示を拡大または縮小します。
5. **レイアウト**: メニュー内のレイアウトオプションから、単一ページ表示と見開き表示を切り替えます。

## オプション

### 表紙ページ設定

- **Type A**（Adobe Acrobat Reader互換）
`PageLayout` が `TwoPageRight` または `TwoColumnRight` の場合は表紙ページを含めます。
それ以外の場合は表紙ページを含めません。

- **Type B**
`Direction` が `L2R` で、`PageLayout` が `TwoPageRight` または `TwoColumnRight` の場合は表紙ページを含めます。
`Direction` が `R2L` で、`PageLayout` が `TwoPageLeft` または `TwoColumnLeft` の場合は表紙ページを含めます。
それ以外の場合は表紙ページを含めません。

## インストール（ソース）

### 前提条件

- macOS 26.6
- Xcode 26.6

### Xcodeでのビルド手順

#### 1. 新規プロジェクトを作成

1. **Xcode** を起動します。
2. **"Create a new Xcode project..."** を選択し、**"Next..."** をクリックします。
3. プラットフォームに **"iOS"**、アプリケーションタイプに **"App"** を選択し、**"Next..."** をクリックします。
4. プロジェクト設定を入力します。
- **Product Name**: `MihirakiPDFViewer`（任意）
- **Organization Identifier**: `com.yourname`（任意）
- **Interface**: `SwiftUI`
- **Language**: `Swift`
- **Storage**: `None`（デフォルト）
5. 保存先を選択し、**"Create"** をクリックします。

#### 2. ソースファイルを取り込む

1. GitHubからソースコードをダウンロードします。
2. `Sources` フォルダ内のフォルダ（`App`、`Managers`、`Models`、`ViewModels`、`Views`）を、Xcode左側の **Project Navigator**（ファイルツリー）へドラッグ＆ドロップします。
3. 表示されるダイアログ（Add to "MihirakiPDFViewer"）で、次のように設定します。
- **Destination**: `Create groups` を選択（フォルダ構成を維持するため重要）
- **Options**: `Copy items if needed` にチェック

#### 3. エントリーポイント（Appファイル）を変更

デフォルトでは、Xcodeは自動生成されたファイルを使ってプロジェクトを起動するよう設定されています。提供されているコードを使うように更新する必要があります。

1. XcodeのProject Navigatorで、自動生成された `[Project Name]App.swift` ファイルを削除します。
2. `Sources/App/MihirakiPDFViewerApp.swift` がプロジェクトに含まれていることを確認します。

#### 4. ビルドして実行

1. Xcodeツールバーの実行ボタン（**▶️**）右側にあるデバイス選択メニューをクリックし、**iPadシミュレータ**（例: "iPad Pro"）を選択します。
2. **▶️（Run）** ボタンをクリックするか、キーボードで `Command + R` を押します。
3. シミュレータが起動し、PDFファイルを選択する画面が表示されればセットアップ成功です。

### トラブルシューティング

- **エラーが発生する場合**: `import PDFKit` に関するエラーが発生した場合は、プロジェクトの **Frameworks, Libraries, and Embedded Content** に `PDFKit` が含まれているか確認してください（通常はデフォルトで含まれています）。
- **"File not found" エラー**: XcodeのProject Navigatorでファイルが赤く表示される場合は、ファイルパスが正しくリンクされていません。そのファイルを削除し、ドラッグ＆ドロップで再度追加してください。

## AIの主な役割

- 初期コードの自動生成（Cline & gemma-4-26b-a4b-qat）
- デバッグ提案（Cline & gemma-4-26b-a4b-qat）
- エージェント型コーディング（Xcode & Codex）
- アプリアイコンとチップ画像の作成（ChatGPT）

## 参考資料

1. [PDFのページ表示設定について理解する](https://qiita.com/TETSURO1999/items/e7a69026bdf8b5e8c631)

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細は [LICENSE](LICENSE) ファイルを参照してください。

## バージョン履歴

- **v0.1.0** - 2026/08/16: 初回リリース。
- **v0.2.0** - 2026/08/19: 投げ銭機能を追加。
