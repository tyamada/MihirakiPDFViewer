# MihirakiPDFViewer

A simple and intuitive PDF viewer suitable for displaying right-bound books 
(such as Japanese books).

When opening a PDF, the page layout and scroll direction settings are 
detected. Display the PDF in Single Page or Two Page view.

This software was coded using generative AI.

## Features

- **View PDF Documents**: Open and read PDF files seamlessly.
- **Search**: Quickly find text within your PDF documents.
- **Layout Options**: Switch between single page and two page views.
- **Settings**: Customize your viewing experience.
- **Zooming**: Intuitive zoom gestures for better readability.

## How to Use

1. **Open a PDF**: Use the file picker to select a PDF file from your device 
or iCloud Drive.
2. **Navigate**: Swipe through pages or use the slider to move through 
the document.
3. **Menu**: Tap to toggle the display of menus and sliders.
4. **Search**: Type in the search bar to find specific text within the PDF.
5. **Zoom**: Use pinch-to-zoom gestures to enlarge or reduce the view. Press 
and hold, then drag to scroll.
6. **Layout**: Switch between single-page and two-page views using the layout 
options in the menu.

## Options

### Cover Page Settings

- **Type A** (Adobe Acrobat Reader compatible)
Includes a cover page if `PageLayout` is 'TwoPageRight' or 'TwoColumnRight';
otherwise, no cover page.
- **Type B**
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
- Creating App Icon & Tip images (ChatGPT)

## References

1. [Demystifying PDF Page Display Settings](https://qiita.com/TETSURO1999/items/e7a69026bdf8b5e8c631)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) 
file for details.

## Version History

- **v0.1.0** - 2026/08/16: Initial Release.
- **v0.2.0** - 2026/08/19: Add a tipping feature.
- **v0.2.1** - 2026/08/20: Changed README.md to the Japanese version.
- **v0.2.2** - 2026/08/21: Added automated tests.
- **v0.3.0** - 2026/08/23: updated UI, Added zoom dragging, and fixed cover sizing.
