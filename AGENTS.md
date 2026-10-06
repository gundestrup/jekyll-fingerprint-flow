# AGENTS.md — jekyll-fingerprint-flow

Jekyll 4 plugin: per-site post-write content-hash cache busting (default
priority 12, configurable from 11–19). Adds `?v=<md5>` to supported local
asset URLs in generated HTML, including markup emitted by themes and plugins.

## Commands

- `bundle install`
- `bundle exec rake quick` — rubocop + rspec (fast loop)
- `bundle exec rake ci` — full gate: + bundler-audit, semgrep (local
  `.semgrep.yml` rules), package check
- CI also runs a separate `semgrep ci` job — org policy on the Semgrep
  AppSec Platform (`SEMGREP_APP_TOKEN` repo secret)
- `bundle exec rspec` — specs only
- Release: `rake "version:bump[patch|minor|major]"` + dated CHANGELOG
  entry, then tag `vX.Y.Z` and push — CI publishes via OIDC.

## Architecture

```text
lib/jekyll/fingerprint_flow.rb    # per-site :post_write dispatcher at 11..19
  rewriter.rb                     # walks _site/**/*.html|htm and confines writes
  html_document_rewriter.rb       # exact HTML URL attributes + byte-span updates
  html_tag_scanner.rb             # source-preserving tag scan; skips comments
                                   #   and raw-text contents
  html_tag_parser.rb              # start tags + exact attribute value spans
  srcset_rewriter.rb              # candidate parsing, including data URLs
  url_tagger.rb                   # URL classify/resolve/query merge + containment
  hasher.rb                       # content MD5, memoized once per path per build
  configuration.rb                # enabled/priority/extensions/exclude validation
```

## Conventions

- `# frozen_string_literal: true`, double quotes, RuboCop clean
  (line length 100, `Metrics/BlockLength` off for specs).
- Tag = `Digest::MD5.file(path)[0,10]` — a pure function of output bytes.
  Hash each unique output file once per build; do not persist digests keyed only
  by path/mtime/size because preserved timestamps can reuse stale content tags.
- Query-param tagging (`?v=`), never renamed files — keeps precompressed
  `.br`/`.zst`/`.gz` siblings and direct links working. The default pipeline is
  normal post-write work (20), fingerprinting (12; configurable 11–19), then
  compression (10; configurable 0–10).
- Rewrite only exact URL-bearing HTML attributes using source byte spans; do
  not serialize whole documents or scan comments, raw-text nodes, JavaScript
  strings, or unrelated attributes.
- `srcset` candidates are parsed so commas within data URLs remain intact.
- Resolved files and symlink targets must remain under `site.dest`; skip symlinked HTML outputs.
- CSS `url()`/`@import`, inline CSS, JavaScript runtime references, and
  non-HTML outputs are intentionally outside the supported scope.
- Specs use `Dir.mktmpdir` fixtures and real Jekyll builds in
  `spec/integration_spec.rb`.

## Do NOT

- Do not commit `_site/` output, `.jekyll-cache/`, `coverage/`, `*.gem`.
- Do not tag URLs whose target file does not exist — broken refs stay broken.
- Do not weaken destination containment or rewrite arbitrary text strings.
