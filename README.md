# MihirakiPDFViewer

English | [日本語](README_ja.md)

A simple and intuitive PDF viewer suitable for displaying right-bound books
(such as Japanese books).

When opening a PDF, the page layout and scroll direction settings are
detected. Display the PDF in Single Page or Two Page view.

This software was coded using generative AI.

## Features

- **Right-to-Left and Left-to-Right Support**: Uses the PDF direction to
  provide natural page movement for both reading directions.
- **Single-Page and Two-Page Views**: Switch layouts and adjust cover-page
  handling to match the document.
- **Search and Zoom**: Search text within a PDF, pinch to zoom, and drag
  while zoomed in.
- **Password-Protected PDFs**: Open documents that require a user password.
- **Rendering Options**: Enable high-quality rendering and sharpness from
  Settings when needed.
- **Reading Session Restoration**: Reopen the last document and continue
  from the previous page after relaunching the app.

## How to Use

1. **Open a PDF**: Use the file picker to select a PDF from your device or
   iCloud Drive. You can also open a PDF sent to the app from another app.
2. **Unlock a Protected PDF**: If the document requires a user password,
   enter it when prompted and select **Unlock**.
3. **Navigate Pages**: Swipe or use the page slider. Page movement follows
   the selected left-to-right or right-to-left reading direction.
4. **Show or Hide Controls**: Tap the document to toggle the toolbar and
   page slider.
5. **Zoom and Pan**: Pinch to zoom in or out. While zoomed in, long-press
   and drag to move around the page.
6. **Search**: Enter text in the search field. Matching text is highlighted
   in the document.
7. **Adjust the Layout**: In Settings, select single-page or two-page view,
   reading direction, and cover-page handling.
8. **Adjust Rendering**: Enable high-quality rendering or sharpness in
   Settings when the PDF needs clearer text and lines.
9. **Close or Resume**: Close the current document from the toolbar, or
   leave it open to resume from the same page after relaunching the app.

## Sample PDF

Try MihirakiPDFViewer with these sample PDFs.

### THE TRY-IT CLUB EPISODE 1 THE BREAK-TIME MAP (English)

[Open the English sample PDF](docs/sample/tameshibu_episode1_en.pdf)

### THE TRY-IT CLUB EPISODE 2 ROOM TO GROW (English)

[Open the English sample PDF](docs/sample/tameshibu_episode2_en.pdf)

### ためし部 第１話 ひと息マップ (Japanese)

[Open the Japanese sample PDF](docs/sample/tameshibu_episode1_ja.pdf)

### ためし部 第２話 机、ひろがる。 (Japanese)

[Open the Japanese sample PDF](docs/sample/tameshibu_episode2_ja.pdf)

### 해봄부 제1화 한숨 돌림 지도 (Korean)

[Open the Korean sample PDF](docs/sample/tameshibu_episode1_ko.pdf)

### 해봄부제2화 책상이 넓어지다 (Korean)

[Open the Korean sample PDF](docs/sample/tameshibu_episode2_ko.pdf)

### 试试社 第1话 歇口气地图 (Chinese (Simplified))

[Open the Simplified Chinese sample PDF](docs/sample/tameshibu_episode1_zh_cn.pdf)

### 试试社 第2话 桌子变大了 (Chinese (Simplified))

[Open the Simplified Chinese sample PDF](docs/sample/tameshibu_episode2_zh_cn.pdf)

## Pricing and Supporting the Developer

MihirakiPDFViewer is free to use. Core features such as PDF viewing,
zooming, search, single-page view, and two-page view are available without
feature restrictions, regardless of whether you make a purchase.

In the App Store version, optional supporter icons are available as
non-consumable in-app purchases through StoreKit. These purchases are
voluntary and are not used to remove ads or unlock restricted viewer
features.

The following supporter icons are available:

- `supporter_icon_bronze`: Bronze icon
- `supporter_icon_silver`: Silver icon
- `supporter_icon_gold`: Gold icon

Each purchase permanently unlocks its corresponding alternate app icon.
Purchases can be restored on another supported device using the same Apple
Account from the supporter icon screen in Settings.

## Options

### Cover Page Settings

- **Standard Mode**
Includes a cover page if `PageLayout` is 'TwoPageRight' or 'TwoColumnRight';
otherwise, no cover page.
- **Compatibility Mode**
Includes a cover page if `Direction` is 'L2R' and `PageLayout` is
'TwoPageRight' or 'TwoColumnRight';
includes a cover page if `Direction` is 'R2L' and `PageLayout` is
'TwoPageLeft' or 'TwoColumnLeft';
otherwise, no cover page.

## Installation (Source)

### Prerequisites
- macOS 26.6
- Xcode 26.6

### Build Steps in Xcode

#### 1. Create a New Project
1. Launch **Xcode**.
2. Select **"Create a new Xcode project..."** and click **"Next..."**.
3. Select **"iOS"** as the platform and **"App"** as the application type,
then click **"Next..."**.
4. Enter the project settings:
- **Product Name**: `MihirakiPDFViewer` (optional)
- **Organization Identifier**: `com.yourname` (optional)
- **Interface**: `SwiftUI`
- **Language**: `Swift`
- **Storage**: `None` (default)
5. Choose a save location and click **"Create"**.

#### 2. Import Source Files
1. Download the source code from GitHub.
2. **Drag and drop** the folders located inside the `Sources` folder (`App`,
`Managers`, `Models`, `ViewModels`, `Views`) into the **Project Navigator**
(file tree) on the left side of Xcode.
3. In the dialog that appears (Add to "MihirakiPDFViewer"), configure
the settings as follows:
- **Destination**: Select `Create groups` (*Important: to maintain the
folder structure*)
- **Options**: Check the box for `Copy items if needed`

#### 3. Modify the Entry Point (App File)
By default, Xcode is configured to launch the project using an automatically
generated file. You need to update this to use the provided code instead.

1. In the Xcode Project Navigator, delete the automatically generated
`[Project Name]App.swift` file.
2. Ensure that `Sources/App/MihirakiPDFViewerApp.swift` is included in the
project.

#### 4. Build and Run
1. Click the device selection menu to the right of the Run button (**▶️**)
in the Xcode toolbar and select an **iPad simulator** (such as "iPad Pro").
2. Click the **▶️ (Run)** button or press `Command + R` on your keyboard.
3. If the simulator launches and displays the screen for selecting a PDF
file, the setup was successful.

### Troubleshooting
*   **If an error occurs**: If you encounter an error with `import PDFKit`,
check if `PDFKit` is included in the project's **Frameworks, Libraries,
and Embedded Content** section (it is usually included by default).
*   **"File not found" error**: If a file appears in red in the Xcode
Project Navigator, the file path is not linked correctly. Delete the file
and add it again by dragging and dropping it.

## Key roles of AI

- Automatic generation of initial code (Cline & gemma-4-26b-a4b-qat)
- Debugging suggestions (Cline & gemma-4-26b-a4b-qat)
- Change code and bug fixes (Xcode & Codex)
- Creating app icon and supporter icon images (ChatGPT)

## References

1. [Unraveling the Mystery of PDF Page Display Settings](https://qiita.com/TETSURO1999/items/e7a69026bdf8b5e8c631)
2. [Adobe Systems, PDF Reference Sixth Edition (Version 1.7), June 2006](https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/pdfreference1.7old.pdf)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE)
file for details.

## Version History

- **v0.1.0** - 2026/08/16: Initial Release.
- **v0.2.0** - 2026/08/19: Add a tipping feature.
- **v0.2.1** - 2026/08/20: Changed README.md to the Japanese version.
- **v0.2.2** - 2026/08/21: Added automated tests.
- **v0.3.0** - 2026/08/26: Updated UI, Added zoom dragging, and fixed cover sizing.
- **v0.4.0** - 2026/08/30: Changed cover page settings.
