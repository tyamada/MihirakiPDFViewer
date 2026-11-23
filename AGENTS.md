# Repository Instructions

## Build Number Updates

Whenever `CURRENT_PROJECT_VERSION` or another build-number source is updated, treat the change as a release-documentation update as well.

Before completing the change:

1. Review the in-app Help screen and update its content to match the current UI, settings, diagnostics, and supported features.
2. Review `LICENSE` and update any version-dependent, year-dependent, attribution, or distribution information when needed.
3. Review and update both `README.md` and `README_ja.md` so their feature descriptions, screenshots, requirements, and usage instructions match the current app.
4. Review every `docs/*.html` file and update all applicable localized pages to match the current app specification. Keep equivalent content synchronized across languages.
5. Verify that no obsolete feature names, screen descriptions, version/build references, or unsupported behavior remain in these files.

Do not consider a build-number update complete until these reviews have been performed. Files that require no textual change may remain untouched, but they must still be checked.
