> **Status (2026-11-26):** **1.1.2 (18)** is available on the App Store in 11 countries and regions (Japan, the United States, South Korea, Taiwan, Hong Kong, Macau, Canada, the United Kingdom, Australia, New Zealand, and Singapore). **1.1.3 (19)** is a local release candidate completing German and French localizations and fixing iPhone SE layout truncation; Germany and France distribution remains on hold pending EU DSA review approval and 1.1.3 release. [Prior release record (2026-11-23)](release-notes/2026-11-23.md).

# MihirakiPDFViewer

The English display name is **Mihiraki: Two-Page PDF Reader**, Japanese is **見開きPDFビューア**, and Korean remains **미히라키 PDF 뷰어**. Other localized names follow `InfoPlist.xcstrings`; unsupported languages fall back to English. The project name and repository URLs remain unchanged.

English | [日本語](README_ja.md)

A simple and intuitive PDF viewer suitable for displaying right-bound books
(such as Japanese books).

When opening a PDF, the page layout and scroll direction settings are
detected. Display the PDF in Single Page or Two Page view.

This software was coded using generative AI.

## Features

- **Right-to-Left and Left-to-Right Support**: Uses the PDF direction to
  provide natural page movement for both reading directions. Right-to-left
  documents open on their first page instead of jumping to the last page.
- **Single-Page and Two-Page Views**: Portrait-shaped reading areas default to
  single-page view. Switch layouts and adjust cover-page handling to match the document.
- **Search and Zoom**: Search text within a PDF, pinch to zoom, and drag
  while zoomed in.
- **Table of Contents**: Open a PDF's hierarchical outline from the reader,
  browse long documents efficiently, and jump directly to a selected page.
- **Password-Protected PDFs**: Open documents that require a user password.
- **Rendering Options**: Enable high-quality rendering and sharpness from
  Settings when needed.
- **Reading Session Restoration**: Reopen the last document and continue
  from the previous page after relaunching the app.
- **Downloadable Sample PDFs**: Browse samples by language using a validated online catalog, the last valid saved list, or the bundled 51-entry fallback (PDF files are downloaded on demand, not bundled),
  download a sample to the device, open it in the viewer, and delete the local
  copy when it is no longer needed. Downloads over mobile data require
  confirmation.
- **On-Device Diagnostics**: Run checks for app information, local storage,
  and PDF rendering, then optionally share a result that includes the test
  time, device model name and identifier, OS version, and app version.
- **Privacy-Safe App Logs**: Review and optionally share 24 hours of diagnostic
  events for investigating crashes, slowdowns, operation issues, and display
  issues. Generated logs exclude document contents, file names and
  paths, search terms, and passwords.

Diagnostic test results and app logs remain on the device unless you explicitly
use the Share button. The app does not automatically send them outside the
device. Logs are limited to 2,000 entries; entries older than 24 hours are removed
when logs are read or recorded, not by a timer while the app is stopped.

## Privacy

Open **Privacy Policy** at the top of Settings or in App Information, before
selecting a PDF or while reading. No purchase or login is required.
Disk-space values and the storage check are excluded from shared diagnostic
results. Processing logs contain elapsed durations, never raw system uptime.
The Privacy Manifest retains the reasons for app-only preferences, elapsed-time
measurement, and on-device disk-space display. It also declares diagnostic,
performance, product-interaction, and search-history data when users send generated
reports to the support address and the developer retains them: App Functionality,
linked to the user, and not used for tracking. This does not add automatic sending.

## How to Use

1. **Open a PDF**: Use the file picker to select a PDF from your device or
   iCloud Drive. You can also open a PDF sent to the app from another app.
2. **Try a Sample PDF**: Choose **Browse Sample PDFs**, select a language,
   and download a sample. A downloaded sample can be opened or deleted from
   the same screen. The app asks before downloading over mobile data.
3. **Unlock a Protected PDF**: If the document requires a user password,
   enter it when prompted and select **Unlock**.
4. **Navigate Pages**: Swipe or use the page slider. Page movement follows
   the selected left-to-right or right-to-left reading direction.
5. **Show or Hide Controls**: Tap the document to toggle the toolbar and
   page slider.
6. **Zoom and Pan**: Pinch to zoom in or out. While zoomed in, long-press
   and drag to move around the page.
7. **Search**: Enter text in the search field. Matching text is highlighted
   in the document.
8. **Adjust the Layout**: In Settings, select single-page or two-page view,
   reading direction, and cover-page handling. **Single Page in Portrait** is on by default
   and displays one page at a time in portrait-shaped reading areas, including wide
   iPad layouts. Turn it off to keep the selected two-page setting in portrait.
9. **Adjust Rendering**: Enable high-quality rendering or sharpness in
   Settings when the PDF needs clearer text and lines.
10. **Close or Resume**: Close the current document from the toolbar, or
   leave it open to resume from the same page after relaunching the app.
11. **Use the Table of Contents**: Tap the list button in the reader to open
    the PDF outline and jump directly to a chapter or section. An empty-state
    message appears when the PDF does not contain an outline.
12. **Run Diagnostics**: Open **Diagnostics** from Settings, then choose
    **Device Tests** to check device and app information, memory, cache and
    available storage, and PDF rendering. Choose **App Logs** to review recent
    diagnostic events, or **Report a Problem** to prepare a GitHub Issues
    report. Results and logs are shared only when you explicitly choose Share.

## Sample PDF


[Browse sample PDF downloads](https://tyamada.github.io/manga-prompt-kit/samples/en/)

Development-source catalog updates: opening the sample list checks the [latest manifest](https://raw.githubusercontent.com/tyamada/manga-prompt-kit/main/releases/pdf-manifest.json) without downloading PDFs automatically. Only a completely validated list is saved atomically. Network or validation failures retain the previous valid list or bundled fallback. Each PDF uses its entry’s fixed Release URL, size and SHA-256. Existing IDs, language filters, local filenames and downloaded PDFs are preserved. This source change is not yet distributed in the App Store.

The 51 PDFs (episodes 1–3, 17 language/region variants) use the fixed [manga-pdf-20261103-v1 Release](https://github.com/tyamada/manga-prompt-kit/releases/tag/manga-pdf-20261103-v1). Creator: こまいろ日和 / Komairo Hiyori (Takuma Yamada). CC BY 4.0 and embedded third-party notices apply. Existing downloads keep their local filenames and offline access; legacy URLs remain available during migration.

Try MihirakiPDFViewer with these sample PDFs.

## Pricing and Supporting the Developer

MihirakiPDFViewer is free to use and has no ads. Core features such as PDF
viewing, sample downloads, zooming, search, single-page view, and two-page
view are available without feature restrictions, regardless of whether you
make a purchase.

In the App Store version, optional supporter icons are available as
non-consumable in-app purchases through StoreKit. These purchases are
voluntary and are not used to remove ads or unlock restricted viewer
features.

The purchase-screen headings are Bronze, Silver, and Gold in all 13 languages. Prices come from StoreKit and appear only on the purchase buttons.

The app supports the following non-consumable items:

- `supporter_icon_bronze`: Bronze icon
- `supporter_icon_silver`: Silver icon
- `supporter_icon_gold`: Gold icon
- `supporter_badge_koyomi_v2`: Release Commemorative Koyomi Badge

Bronze, Silver, and Gold purchases permanently unlock their corresponding alternate app icons. Koyomi is excluded from the purchase list and does not change the app icon. In the next development version, both existing and new users receive it free when eligibility is evaluated before January 1, 2028 at 00:00 JST (through December 31, 2027), using the device clock. No purchase, redemption code, account lookup, or network connection is required. The grant is saved locally and remains after the deadline; a new grant shows an acquisition notice. Tap a badge in App Information to view its enlarged image, name, and description.

Existing StoreKit badge rights remain valid and produce one badge together with a local free grant. Settings → Support → Restore Purchases restores eligible StoreKit purchases using the same Apple Account; it does not recover a lost local free grant after the deadline. Deleting the app may remove the local grant. Support still provides code redemption for eligible purchased items.

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
- Xcode 26.6 (CI configuration), or a compatible later version. Also verified locally with Xcode 27.1.

### Command-line build and tests

Install Xcode, its first-launch components, and an iOS simulator runtime. Verify that `xcode-select -p` points to the Xcode Developer directory. Python 3 is used for documentation checks and simulator selection. No external Swift packages or CocoaPods installation is required.

```bash
git clone https://github.com/tyamada/MihirakiPDFViewer.git
cd MihirakiPDFViewer
xcodebuild -list -project MihirakiPDFViewer.xcodeproj
# Use a scheme listed above (CI when available; otherwise MihirakiPDFViewer).
xcodebuild build -project MihirakiPDFViewer.xcodeproj -scheme CI \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO
python3 scripts/ci_simulator.py
# Replace SIMULATOR_UUID with the SIMULATOR_ID printed by the command above.
xcodebuild test -project MihirakiPDFViewer.xcodeproj -scheme CI \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -only-testing:MihirakiPDFViewerTests CODE_SIGNING_ALLOWED=NO
```

Simulator builds do not require the author's certificate or private key. To install on a physical device, select your connected device in Xcode, choose your own Team and an available Bundle Identifier under Signing & Capabilities, then Run. Keep signing keys and profiles out of Git. `Products.storekit/Configuration.storekit` is a shareable local product-testing definition, not a production purchase credential.

A fresh checkout missing `Assets.xcassets` or `AppIcon` cannot build from source alone. These are required repository inputs, not private credentials. Use a revision containing the asset fix. Publish `MihirakiPDFViewer/Assets.xcassets/`, `Info.plist`, the shared `CI.xcscheme`, `PrivacyInfo.xcprivacy`, and any added Swift sources together. Older revisions without the `CI` scheme or helper scripts cannot use all current commands unchanged.

### Continuous integration

GitHub Actions checks changes pushed to `testing` and `main`, and pull requests
targeting either branch. Documentation changes run offline HTML structure,
local link, anchor, and image-reference checks. App, test, localization, and
project changes run the shared `CI` scheme's unit tests on an iPad simulator
(iOS 26.5 or newer), using Xcode 26.6 on `macos-26`.

The `iOS checks` manual workflow can also run three primary-screen UI smoke
tests by enabling `ui_tests`. Manual dispatch becomes available after the
workflow is present on the default branch; select `testing` to test that branch.
Logs and `.xcresult` bundles are retained for seven days. GitHub Pages continues
to publish only from `main`'s `/docs` directory; these checks do not deploy.
Path-filtered workflows should not be mandatory branch checks without accounting
for runs skipped when unrelated files change.

Run documentation checks locally with `python3 scripts/check_docs.py`.
These checks validate the site's explicit tag nesting and local `href`/`src`
references, not full HTML conformance or external website availability.
Include the shared scheme and the app asset catalog when committing CI setup
so a fresh checkout has the same build resources as the local project.

### Build Steps in Xcode

1. Clone this repository, including the assets and resource catalogs.
2. Open `MihirakiPDFViewer.xcodeproj` and select the shared `CI` scheme.
3. Select an iPhone or iPad simulator running iOS/iPadOS 26.5 or later.
4. Build and run. Use your own development team when signing for a device.

The app target must include `PrivacyInfo.xcprivacy` in its resources. For a
release, inspect both the archive and exported IPA for the manifest.

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

- **1.1.3 build 19 — local release candidate, 2026/11/26**: Completed German
  and French localizations (`Localizable.xcstrings`), shortened German reading-direction
  segment labels and supporter-icon apply button to prevent truncation on iPhone SE,
  and verified German/French primary screens on a physical iPhone SE (3rd generation).
- **1.1.2 build 18 — released**: Expanded distribution to 11 countries and regions
  (Japan, the United States, South Korea, Taiwan, Hong Kong, Macau, Canada, the United Kingdom,
  Australia, New Zealand, and Singapore).
- **1.0.4 build 14 — local source candidate, 2026/11/07**: Uses price-free
  Bronze, Silver and Gold headings in all 13 languages; purchase buttons retain
  StoreKit prices. Retains the four ShareLink-related collected-data declarations.
  No Archive, IPA export, upload or submission has been performed for build 14.
  Build 13 Archive, exported IPA and Privacy Report are retained separately;
  their checks and the reported iPhone/Sandbox results do not validate build 14.
  Final build 14 artifact, device and purchase/restoration checks remain pending.

- **1.0.4 build 12 — local candidate, 2026/10/24**: Added accessible,
  localized privacy-policy links and a Privacy Manifest; excluded disk-space
  information from diagnostic sharing. Includes the development features below.
  Standardized app names and renamed the Release Commemorative Koyomi Badge.
  This candidate has not been exported, uploaded, or submitted; device, VoiceOver,
  Privacy Report, and new IPA checks remain pending.

- **Unreleased** - 2026/10/09: Added downloadable multilingual sample PDFs,
  updated them to the second edition, added language filtering, device
  diagnostics and privacy-safe logging, and clarified the sample PDF license
  and attribution. Fixed right-to-left documents opening on the last page and
  reorganized Settings controls and Help content. Added a hierarchical PDF
  table of contents with direct page navigation, expanded Diagnostics with
  problem-report guidance, and added supporter badges and promotion-code
  guidance.
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
