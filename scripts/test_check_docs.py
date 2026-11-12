"""Offline regression checks for README links and the documentation validator."""
from pathlib import Path
import tempfile
import unittest
from check_docs import check, check_readmes


class DocumentationChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for name in ("README.md", "README_ja.md"):
            (self.root / name).write_text("# App\n")

    def tearDown(self):
        self.temp.cleanup()

    def test_existing_local_links_and_remote_links(self):
        (self.root / "guide.pdf").write_bytes(b"sample")
        (self.root / "README.md").write_text('[Guide](guide.pdf) [Remote](https://example.invalid/absent)')
        self.assertEqual(check_readmes(self.root), [])

    def test_missing_markdown_image_is_reported(self):
        (self.root / "README.md").write_text('![Screen](absent.png)')
        self.assertTrue(any("absent.png" in error for error in check_readmes(self.root)))

    def test_missing_embedded_html_image_is_reported(self):
        (self.root / "README_ja.md").write_text('<img src="missing.png" alt="Screen">')
        self.assertTrue(any("missing.png" in error for error in check_readmes(self.root)))

    def test_encoded_paths_queries_and_fragments(self):
        (self.root / "a b.pdf").write_bytes(b"sample")
        (self.root / "README.md").write_text('[Guide](a%20b.pdf?download=1#page=2) [Section](#use)')
        self.assertEqual(check_readmes(self.root), [])

    def test_parent_directory_does_not_satisfy_a_link(self):
        (self.root / "README.md").write_text('[Outside](../README.md)')
        self.assertTrue(any("escapes" in error for error in check_readmes(self.root)))

    def test_html_missing_anchor_is_reported(self):
        docs = self.root / "docs"
        docs.mkdir()
        (docs / "index.html").write_text('<html lang="en"><head><title>App</title></head><body><a href="#absent">Go</a></body></html>')
        self.assertTrue(any("missing anchor" in error for error in check(docs)))


if __name__ == "__main__":
    unittest.main()
