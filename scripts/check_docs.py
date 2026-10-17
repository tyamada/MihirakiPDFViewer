"""Check the site's explicitly closed HTML and local href/src references offline.

This is a lightweight structural check, not a complete HTML conformance validator.
External URLs are intentionally excluded to avoid network-dependent CI failures.
"""

from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


VOID_TAGS = set("area base br col embed hr img input link meta param source track wbr".split())


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.path = path
        self.ids = set()
        self.references = []
        self.stack = []
        self.errors = []
        self.has_language = False
        self.has_title = False
        self.feed(path.read_text(encoding="utf-8"))
        self.close()
        if self.stack:
            self.errors.append(f"unclosed tags: {self.stack}")
        if not self.has_language or not self.has_title:
            self.errors.append("missing html lang or title")

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.has_language |= tag == "html" and bool(attrs.get("lang"))
        self.has_title |= tag == "title"
        if "id" in attrs:
            if attrs["id"] in self.ids:
                self.errors.append(f"duplicate id: {attrs['id']}")
            self.ids.add(attrs["id"])
        for name in ("href", "src"):
            if attrs.get(name):
                self.references.append((self.getpos()[0], attrs[name]))
        if tag not in VOID_TAGS:
            self.stack.append(tag)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID_TAGS:
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        if not self.stack or self.stack[-1] != tag:
            self.errors.append(f"line {self.getpos()[0]}: unexpected closing tag </{tag}>")
        else:
            self.stack.pop()


def check(root):
    root = root.resolve()
    pages = {path: Page(path) for path in sorted(root.rglob("*.html"))}
    errors = []
    if not pages:
        return ["No HTML pages found"]
    for path, page in pages.items():
        errors.extend(f"{path.relative_to(root)}: {error}" for error in page.errors)
        for line, reference in page.references:
            url = urlsplit(reference)
            if url.scheme or url.netloc:
                continue
            # Root-relative links do not work under this project's Pages base URL.
            if url.path.startswith("/"):
                errors.append(f"{path.name}:{line}: use a relative URL: {reference}")
                continue
            target = (path.parent / unquote(url.path)).resolve() if url.path else path
            if target.is_dir():
                target /= "index.html"
            if not target.is_relative_to(root) or not target.is_file():
                errors.append(f"{path.name}:{line}: missing local target: {reference}")
            elif url.fragment and target in pages and unquote(url.fragment) not in pages[target].ids:
                errors.append(f"{path.name}:{line}: missing anchor: {reference}")
    return errors


if __name__ == "__main__":
    errors = check(Path(__file__).resolve().parents[1] / "docs")
    if errors:
        raise SystemExit("\n".join(errors))
    print("Documentation HTML structure and local references passed.")
