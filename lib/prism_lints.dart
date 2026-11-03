/// Lint rules that keep a Prism design system honest.
///
/// Prism's components all read [PrismTokens] and [PrismColors], so one override
/// restyles a whole app. That guarantee ends the moment application code starts
/// writing its own `EdgeInsets.all(16)` or `BorderRadius.circular(12)`: the app
/// now has two sources of truth, and changing a token no longer changes
/// everything.
///
/// These rules close that gap by reporting a literal that duplicates a token and
/// naming the token it duplicates.
///
/// ## Install
///
/// ```yaml
/// dev_dependencies:
///   custom_lint: ^0.8.0
///   prism_lints: ^0.1.0
/// ```
///
/// ```yaml
/// # analysis_options.yaml
/// analyzer:
///   plugins:
///     - custom_lint
/// ```
///
/// Then run `dart run custom_lint`. Note that `dart analyze` does not execute
/// custom lint plugins, so CI needs the separate command.
///
/// ## The rules
///
/// | Rule | Reports |
/// |---|---|
/// | `hardcoded_spacing` | `EdgeInsets` and `SizedBox` values that match `PrismTokens.space*` |
/// | `hardcoded_radius` | `BorderRadius.circular` values that match `PrismTokens.radius*` |
/// | `hardcoded_duration` | `Duration` values that match `PrismTokens.duration*` |
/// | `prefer_prism_motion` | any animation duration that ignores reduce motion |
/// | `hardcoded_semantic_color` | a hex copied from `PrismColors` |
///
/// ## Why these stay quiet
///
/// Every rule reports a literal only when it **exactly** matches a token. A value
/// of `13` has no token, so nothing is reported: there is no actionable advice,
/// and a rule that fires on values the user cannot fix gets disabled and then
/// helps nobody.
///
/// All rules are on by default, because custom_lint enables every rule a plugin
/// exposes. To turn one off:
///
/// ```yaml
/// # analysis_options.yaml
/// custom_lint:
///   rules:
///     - hardcoded_spacing: false
/// ```
///
/// `prefer_prism_motion` is the one worth keeping even if you dislike the rest:
/// it reports an accessibility defect rather than a preference, because an
/// animation with a literal duration runs for a user who has asked the platform
/// for less motion.
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/design_system_rules.dart';

/// The plugin entry point custom_lint looks for.
PluginBase createPlugin() => _PrismLints();

class _PrismLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        HardcodedSpacing(),
        HardcodedRadius(),
        HardcodedDuration(),
        PreferPrismMotion(),
        HardcodedSemanticColor(),
      ];
}
