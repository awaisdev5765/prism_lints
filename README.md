# 🔍 prism_lints

<p align="center">
  <b>Keeps a Prism design system honest.</b><br/>
  Reports spacing, radii, durations and colours that duplicate a design token.
</p>

[![pub.dev](https://img.shields.io/badge/pub.dev-prism__lints-0175C2?logo=dart&logoColor=white)](https://pub.dev/packages/prism_lints)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![tests](https://img.shields.io/badge/tests-22%20passing-brightgreen)](test)

---

Every component in [Prism](https://pub.dev/packages/prism_kit) reads `PrismTokens`
and `PrismColors`, which is what makes "change `spaceMd` once and the whole app
changes rhythm together" true. That guarantee ends the moment application code
writes its own `EdgeInsets.all(16)`: the app now has two sources of truth, and
changing a token no longer changes everything.

These rules close that gap. They find a literal that duplicates a token and name
the token it duplicates.

## Install

```yaml
dev_dependencies:
  custom_lint: ^0.8.0
  prism_lints: ^0.1.0
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

```bash
dart run custom_lint
```

> **Note:** `dart analyze` does not execute custom lint plugins, so CI needs the
> separate `dart run custom_lint` command. This surprises people; it is how
> custom_lint works, not something this package can change.

## The rules

| Rule | Reports |
|---|---|
| `hardcoded_spacing` | `EdgeInsets` and `SizedBox` values matching `PrismTokens.space*` |
| `hardcoded_radius` | `BorderRadius.circular` values matching `PrismTokens.radius*` |
| `hardcoded_duration` | `Duration` values matching `PrismTokens.duration*` |
| `prefer_prism_motion` | an animation duration that ignores reduce motion |
| `hardcoded_semantic_color` | a hex copied from `PrismColors` |

### What that looks like

```dart
Padding(
  padding: EdgeInsets.all(16),        // hardcoded_spacing → PrismTokens.spaceMd
  child: SizedBox(
    height: 24,                       // hardcoded_spacing → PrismTokens.spaceLg
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 350),  // prefer_prism_motion
      opacity: 0.5,
      child: const SizedBox.shrink(),
    ),
  ),
)
```

The fixes:

```dart
final tokens = context.prismTokens;
Padding(
  padding: EdgeInsets.all(tokens.spaceMd),
  child: SizedBox(
    height: tokens.spaceLg,
    child: AnimatedOpacity(
      // Zero when the platform asks for reduced motion.
      duration: context.prismMotion(const Duration(milliseconds: 350)),
      opacity: 0.5,
      child: const SizedBox.shrink(),
    ),
  ),
)
```

## Why these rules stay quiet

This is the design decision that matters most, because custom_lint turns **every**
rule a plugin exposes on by default. A noisy rule gets disabled, and then it helps
nobody.

**Every rule reports a literal only when it exactly matches a token.**

| Code | Reported? | Why |
|---|---|---|
| `EdgeInsets.all(16)` | ✅ `spaceMd` | The token exists |
| `EdgeInsets.all(13)` | ❌ | No token is 13. There is nothing actionable to say |
| `SizedBox(height: gap)` | ❌ | Not a literal, so it is not a hard-coded value |
| `Duration(milliseconds: 240)` | ✅ `durationMedium` | The token exists |
| `Duration(milliseconds: 350)` | ❌ from `hardcoded_duration` | No token is 350 — but `prefer_prism_motion` still reports it, because ignoring reduce motion is a defect regardless of naming |
| `context.prismMotion(…)` | ❌ | Already correct |
| `Color(0xFF1B7A4B)` | ✅ | It is one of Prism's fixed semantic colours |
| `Color(0xFF3A7BD5)` | ❌ | A brand colour. Reporting every hex would be unusable |

`prefer_prism_motion` is the one rule worth keeping even if you dislike the rest.
The others are about naming; that one is about a user who asked their platform for
less motion and did not get it.

### One rule per line

`hardcoded_duration` deliberately stays silent on an animated widget's
`duration:` argument, because `prefer_prism_motion` already owns that position
with the stronger message. Both would report the same span, and two warnings on
one line with the same fix is noise rather than thoroughness.

## Turning rules off

All rules are on by default. To disable one:

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - hardcoded_spacing: false
```

Or invert it, and opt in to only what you want:

```yaml
custom_lint:
  enable_all_lint_rules: false
  rules:
    - prefer_prism_motion
```

## Verifying the rules

```bash
cd example
flutter pub get
dart run custom_lint
```

The `example/` folder is a fixture rather than an app. It answers two questions
unit tests cannot:

1. **Do the rules fire on resolved code?** They match
   `InstanceCreationExpression`, and analyzer only produces that node for
   `Duration(…)` and friends *after* resolution. A test that parses a string sees
   a `MethodInvocation` instead, so the dotted-constructor cases can only be
   checked against resolved code.
2. **Do they stay quiet on values with no token?** The bottom half of
   `example/lib/violations.dart` is exactly that, and reports nothing.

Expected: seven reports across six lines, and silence on the rest.

## Requirements

- Dart `^3.5.0`
- `custom_lint` `^0.8.0`
- Works with any Flutter app, whether or not it uses Prism's components. If your
  app has a design system with these token values, the rules apply to it.

## ☕ Support

If these rules save you a design-system drift, you can buy me a coffee:

<p align="center">
  <a href="https://buymeacoffee.com/awaisdev572">
    <img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=%E2%98%95&slug=awaisdev572&button_colour=FFDD00&font_colour=000000&font_family=Lato&outline_colour=000000&coffee_colour=ffffff" alt="Buy Me A Coffee">
  </a>
</p>

## License

MIT — see [LICENSE](LICENSE).
