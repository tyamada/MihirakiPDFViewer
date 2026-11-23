# Sample PDF inputs and legacy availability

User-facing sample downloads are centralized at https://tyamada.github.io/manga-prompt-kit/samples/en/ (Japanese: /samples/ja/). Do not copy manga PDFs into docs/sample when updating the website. App catalog/manifest URLs are machine inputs and remain unchanged.

## Capture and real-PDF integration

Prepare only the required files outside this checkout:

    python3 scripts/prepare_sample_fixtures.py --cache-dir /path/outside/checkout --files tameshibu_episode1_2_en.pdf tameshibu_episode1_2_ja.pdf

Set MIHIRAKI_SAMPLE_PDF_DIR to that directory in the UI test runner environment. The resolver checks the receipt, size, PDF header and SHA-256. Missing/unverified inputs fail explicitly. Use --input-dir to reuse existing matching files, and --manifest with --offline for verified offline preparation. The manifest SHA-256 is pinned to manga-pdf-20261103-v1; updating it requires explicit manifest review. Existing fil/tl naming is resolved without changing app catalog IDs or user caches.

Small generated Regression8 fixtures cover the local selection unit tests. Actual manga coverage is separate in RTLReaderRegressionTests and capture tests; do not count non-executed UI tests as passed. No app installation or device/emulator test execution is authorized by this documentation update.

## Legacy compatibility

Published iOS 1.0.4 (14) embeds 14 https://tyamada.github.io/MihirakiPDFViewer/sample/tameshibu...pdf URLs (episodes 1/2, en/ja/ko/zh_cn/zh_tw/de/fr). Keep all these Pages PDFs available until compatible distributed apps and old-version availability are verified. The 42 docs/sample and 42 local testdata manga PDFs are individually inventoried; identical local copies alone do not authorize removing a published endpoint. No deletion in this change: legacy dependencies, differing fixed-Release hashes, or outstanding build/integration validation remain release gates. SEASIDE_LIVING, other regression PDFs, catalog JSON, downloaded user PDFs and old Releases are retained.

Maintenance: https://github.com/tyamada/manga-prompt-kit/blob/main/docs/sample-download-maintenance.md
