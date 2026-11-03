# prism_lints example

A fixture rather than a runnable app. It exists to answer two questions that
unit tests cannot:

1. **Do the rules fire on resolved code?** The rules match
   `InstanceCreationExpression`, and analyzer only produces that node for
   `Duration(…)` and friends *after* resolution. Unit tests that parse a string
   see a `MethodInvocation` instead, so the dotted-constructor cases can only be
   checked here.
2. **Do they stay quiet on values that have no token?** A rule that fires on
   `EdgeInsets.all(13)` is a rule people disable, and then it helps nobody.

```bash
flutter pub get
dart run custom_lint
```

Expected output is seven reports across six lines — one per violation, with the
`prefer_prism_motion` case deliberately not doubled by `hardcoded_duration` — and
nothing at all on the bottom half of `lib/violations.dart`, which holds the
non-token values, a non-literal, and code that already uses the tokens.
