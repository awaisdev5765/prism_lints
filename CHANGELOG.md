# Changelog

## 0.1.0

Initial release.

### Added
- `hardcoded_spacing` — reports `EdgeInsets` and `SizedBox` values that match a
  `PrismTokens.space*` token.
- `hardcoded_radius` — reports `BorderRadius.circular` values that match a
  `PrismTokens.radius*` token.
- `hardcoded_duration` — reports `Duration` values that match a
  `PrismTokens.duration*` token, and deliberately stays silent on an animated
  widget's `duration:` argument so a line never produces two warnings with the
  same fix.
- `prefer_prism_motion` — reports any animation duration that ignores the
  platform reduce-motion setting. This is the rule carrying an accessibility
  finding rather than a style preference.
- `hardcoded_semantic_color` — reports a hex copied from `PrismColors`.
- 22 unit tests, plus an `example/` fixture that verifies the rules end to end
  against resolved code.
