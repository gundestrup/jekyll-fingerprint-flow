# jekyll-fingerprint-flow

[![Status: Active](https://img.shields.io/badge/status-active-success)](https://github.com/gundestrup/jekyll-fingerprint-flow)
[![CI](https://github.com/gundestrup/jekyll-fingerprint-flow/actions/workflows/ci.yml/badge.svg)](https://github.com/gundestrup/jekyll-fingerprint-flow/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/jekyll-fingerprint-flow)](https://rubygems.org/gems/jekyll-fingerprint-flow)
[![Codecov](https://codecov.io/gh/gundestrup/jekyll-fingerprint-flow/graph/badge.svg)](https://codecov.io/gh/gundestrup/jekyll-fingerprint-flow)
[![Ruby](https://img.shields.io/badge/ruby-%E2%89%A5%203.3-red.svg)](https://www.ruby-lang.org/)
[![Jekyll](https://img.shields.io/badge/jekyll-4.x-blue.svg)](https://jekyllrb.com/)
[![Release](https://img.shields.io/github/v/tag/gundestrup/jekyll-fingerprint-flow)](https://github.com/gundestrup/jekyll-fingerprint-flow/tags)
[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0--or--later-blue.svg)](LICENSE.txt)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/gundestrup/jekyll-fingerprint-flow)
[![CodeFactor](https://www.codefactor.io/repository/github/gundestrup/jekyll-fingerprint-flow/badge)](https://www.codefactor.io/repository/github/gundestrup/jekyll-fingerprint-flow)
[![Semgrep CE](https://img.shields.io/badge/Semgrep_CE-security-success)](https://github.com/gundestrup/jekyll-fingerprint-flow/security/code-scanning)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=gundestrup_jekyll-fingerprint-flow&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=gundestrup_jekyll-fingerprint-flow)

Drop-in content-hash cache busting for Jekyll. After the site is written,
matching local asset URLs in supported attributes of generated `.html`
and `.htm` files receive a content-derived `?v=<md5>` tag:

```html
<link rel="stylesheet" href="/assets/site.css">
<!-- becomes -->
<link rel="stylesheet" href="/assets/site.css?v=3f8a1c2e94">
```

No template changes or asset-pipeline tags are needed. The post-write pass
covers matching URLs emitted by layouts, themes, and other plugins, without
mistaking comments, script text, or unrelated `data-*` attributes for markup.

## Why

Browsers cache static assets aggressively. When a site serves assets with a
long `Cache-Control: max-age`, a new deploy can update the HTML while visitors
keep stale CSS or JavaScript referenced directly by that HTML. Changing the
URL invalidates the browser cache entry, and a **content hash** changes the
URL exactly when the referenced file's bytes change:

- same bytes → same URL → browser cache entry remains valid
- different bytes → new URL → browser fetches the new resource

The digest is deterministic across machines and builds; there is no persistent
version counter or manifest state to synchronize.

Query-param tagging (`?v=`) was chosen over renamed files
(`site-<hash>.css`) deliberately: filenames stay stable, so precompressed
siblings (`.br`, `.zst`, `.gz`) and direct document links keep working. The
post-write order is normal processing (20), fingerprinting (12), then
compression (10), so compressors see the rewritten HTML.

## Install

```ruby
# Gemfile
group :jekyll_plugins do
  gem "jekyll-fingerprint-flow"
end
```

That's it — the next `jekyll build` fingerprints matching references.

## What gets tagged

The plugin scans real start-tag attributes in generated `.html` and `.htm`
files. It edits only the attribute value spans; it does not serialize the
whole document.

| Attribute | Example |
| ----------- | --------- |
| `src` | `<script>`, `<img>`, `<video>`, `<source>`, `<iframe>` |
| `href` | `<link>` and direct links to downloadable files |
| `xlink:href` | legacy SVG links |
| `srcset` | responsive image candidates (descriptors preserved) |
| `poster` | `<video>` poster frames |

A URL is tagged only when **all** of these hold:

- it is local (no scheme, no `//`, not `data:`/`mailto:`/…)
- its extension is in the allowlist (`css js mjs map json xml webmanifest
  png jpg jpeg gif webp avif svg ico woff woff2 ttf otf eot mp4 webm mp3
  wav ogg pdf txt`)
- its target resolves to a real file within `_site` (root-relative paths honor
  `baseurl`; relative paths honor a local `<base href>` when present, otherwise
  resolve from the generated document's directory)

Comments, raw-text elements (`script`, `style`, `textarea`, and similar), and
non-target attributes such as `data-src` are not scanned. External `<base`
URLs are left untouched along with that page's local-looking references,
since the browser would resolve them against the external origin.

`srcset` candidates are parsed separately so commas inside data URLs are not
treated as candidate separators. Candidates that cannot be tagged stay byte-
for-byte as supplied; the attribute is rewritten only if at least one URL
changes.

Existing query strings are preserved — a `?v=` already present is replaced
(not stacked), other parameters are retained, and `#fragments` survive. HTML
entities in attribute values are decoded for URL processing and escaped again
when written.

### Scope boundary

This is a post-write HTML attribute rewriter, not a general parser for every
resource-bearing language. It does **not** rewrite CSS `url()` / `@import`,
inline CSS, JavaScript `fetch()`/dynamic imports, references in JSON/XML, or
other non-HTML output. Such references need format-specific processing; the
plugin intentionally does not guess by rewriting arbitrary strings in source
text.

## Config

All optional — defaults are zero-config:

```yaml
# _config.yml
fingerprint_flow:
  enabled: true              # set false to disable the pass entirely
  priority: 12               # integer 11..19; default 12
  extensions: [.gpx, .bin]   # extra extensions to fingerprint
  exclude:                   # URL path prefixes never rewritten
    - "/internal/"
```

`priority` is a site-configurable integer from 11 through 19 (default 12). A
dispatcher registers at each allowed slot and only the one selected by this
site's config rewrites output. Normal-priority work (20) runs first, then
fingerprinting, then compression (0–10).

## Behaviour notes

- **Content-derived tag.** The value is `md5(file content)[0,10]`, a pure
  function of the output bytes.
- **Build-local memoization.** Each unique resolved file is hashed once per
  build. The memo is not persisted, so preserved mtimes or same-size edits
  cannot make a later build reuse a stale digest.
- **Destination confinement.** Resolved files and symlink targets must remain
  under `_site`; path traversal and external symlinks are skipped. Symlinked
  HTML pages are not rewritten.
- **No mtime churn.** HTML files are written back only when a URL changes, so
  rsync-based deploys do not re-upload untouched pages.
- **HTTP policy is separate.** The plugin changes URLs; it does not set
  `Cache-Control`. The web server still controls freshness. Long-lived browser
  caching is safe when caches key entries by the full URL, including `?v=`.

## Development

```bash
bundle install
bundle exec rake quick   # rubocop + rspec
bundle exec rake ci      # + bundler-audit, semgrep, package check
```

Release: `bundle exec rake "version:bump[patch]"`, add a dated CHANGELOG
entry, commit, `git tag vX.Y.Z && git push --tags` — the release workflow
verifies the tag, builds the gem, attaches it to a GitHub release, and
publishes to RubyGems via OIDC trusted publishing.

## License

AGPL-3.0-or-later — see [LICENSE.txt](LICENSE.txt).
