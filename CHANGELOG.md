# Changelog

## [0.1.0] - 2026-10-04

- Per-site `:site, :post_write` dispatcher that content-tags supported local
  asset URLs after normal-priority processing and before compression (default
  priority 12; configurable from 11 through 19).
- Source-preserving HTML tag/attribute scanning for `.html` and `.htm` output;
  rewrites exact `src`, `href`, `xlink:href`, `srcset`, and `poster` attributes,
  not comments, script/style text, or unrelated `data-*` attributes.
- `srcset` parsing preserves data URLs, candidate descriptors, and unchanged
  formatting; handles local candidates individually.
- `?v=<md5(content)[0,10]>` tags are derived from bytes and memoized only for
  the current build; no persistent stat-keyed cache can return an old digest.
- Resolves local `<base href>` values, honors `baseurl`, rejects targets
  outside `_site` (including traversal and symlinks), and skips symlinked HTML
  outputs so builds cannot write through them.
- Skips external/scheme URLs, non-allowlisted paths, missing targets, and
  pages with invalid base-href encoding; replaces existing `?v=` params and
  preserves other query params and fragments.
- Config: `fingerprint_flow.enabled` (default true),
  `fingerprint_flow.priority` (default 12, integer 11–19),
  `fingerprint_flow.extensions` (extend the allowlist), and
  `fingerprint_flow.exclude` (URL path prefixes never rewritten).
- Writes each HTML file only when an attribute URL actually changes.
