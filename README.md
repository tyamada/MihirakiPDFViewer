# MihirakiPDFViewer

See the [publication and X announcement record (Japanese)](docs/PUBLICATION_STATUS_20261123.ja.md) for the November 23, 2026 checks. Existing pending work remains pending.

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
- **On-Device Diagnostics**: Run checks for app information, local storage,
  and PDF rendering, then optionally share a result that includes the test
  time, device name, OS version, and app version.
- **Privacy-Safe App Logs**: Review and optionally share 24 hours of diagnostic
  events for investigating crashes, slowdowns, operation issues, and display
  issues. Logs exclude personal information, file contents, file names and
  paths, search terms, and passwords.

Diagnostic test results and app logs remain on the device unless you explicitly
use the Share button. The app does not automatically send them outside the
device, and logs older than 24 hours are deleted.

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
10. **Run Diagnostics**: At the bottom of Settings, choose **Run Device Test**
    to run checks on the current device or **View App Logs** to review recent
    diagnostic events. Each results screen has a Share button for sharing only
    when you choose to do so.

## Sample PDF


[Browse sample PDF downloads](https://tyamada.github.io/manga-prompt-kit/samples/en/)

Try MihirakiPDFViewer with these sample PDFs.

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

### Prerequisites and build

Use a compatible macOS and Xcode installation with an iOS simulator runtime. Python 3 is used for documentation checks. No external Swift packages or CocoaPods installation is required.

```bash
git clone https://github.com/tyamada/MihirakiPDFViewer.git
cd MihirakiPDFViewer
xcodebuild -list -project MihirakiPDFViewer.xcodeproj
xcodebuild build-for-testing -project MihirakiPDFViewer.xcodeproj -scheme MihirakiPDFViewer \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO
xcrun simctl list devices available
# Replace SIMULATOR_UUID with an available simulator ID.
xcodebuild test -project MihirakiPDFViewer.xcodeproj -scheme MihirakiPDFViewer \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -only-testing:MihirakiPDFViewerTests CODE_SIGNING_ALLOWED=NO
python3 scripts/check_docs.py
python3 -m unittest discover -s scripts -p 'test_check_docs.py'
```

In Xcode, open the included `MihirakiPDFViewer.xcodeproj`, select a simulator and Run. Creating a new project or manually importing source folders is unnecessary. Simulator builds do not require the author's certificate or private key. For a physical device, choose your own Team and an available Bundle Identifier under Signing & Capabilities. Keep signing keys and profiles out of Git.

## Key roles of AI

- Automatic generation of initial code (Cline & gemma-4-26b-a4b-qat)
- Debugging suggestions (Cline & gemma-4-26b-a4b-qat)
- Change code and bug fixes (Xcode & Codex)
- Creating app icon and supporter icon images (ChatGPT)

## Qiita Article Series

[Qiita series stock list](https://qiita.com/tyamada22/stocks/d4e7a344a6c04dc1115f)

## References

1. [Unraveling the Mystery of PDF Page Display Settings](https://qiita.com/TETSURO1999/items/e7a69026bdf8b5e8c631)
2. [Adobe Systems, PDF Reference Sixth Edition (Version 1.7), June 2006](https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/pdfreference1.7old.pdf)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE)
file for details.

## Sample PDF License

THE TRY-IT CLUB EPISODE 1 THE BREAK-TIME MAP (English)<br>
THE TRY-IT CLUB EPISODE 2 ROOM TO GROW (English)<br>
© 2026 Komairo Hiyori

The portions of this work for which the publisher holds copyright or other licensable rights are made available under the Creative Commons Attribution 4.0 International License (CC BY 4.0).<br>
https://creativecommons.org/licenses/by/4.0/

When reusing this work, provide the title of the work, the author name “Komairo Hiyori,” the original source, and a link to the license. Indicate whether any changes were made.

Generative AI was used to create and translate the text and images in this work. Materials owned by third parties, such as fonts, are subject to their respective licenses. This notice does not restrict the use of any parts that are not protected by copyright or other rights.

## Version History

- **Unreleased** - 2026/10/09: Added downloadable multilingual sample PDFs,
  updated them to the second edition, added language filtering, device
  diagnostics and privacy-safe logging, and clarified the sample PDF license
  and attribution.
- **v1.0.4** - 2026/10/02: Added restoration of supporter icon purchases and
  improved PDF layout stability when controls are shown.
- **v1.0.3** - 2026/09/30: Fixed search highlight alignment on iPad and
  updated the settings reset guidance and translations.
- **v0.4.0** - 2026/08/30: Changed cover page settings.
- **v0.3.0** - 2026/08/26: Updated the UI, added zoom dragging, and fixed cover
  sizing.
- **v0.2.2** - 2026/08/21: Added automated tests.
- **v0.2.1** - 2026/08/20: Changed README.md to the Japanese version.
- **v0.2.0** - 2026/08/19: Added a tipping feature.
- **v0.1.0** - 2026/08/16: Initial release.
