import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../token_values.dart';

/// Flags a spacing literal that duplicates a Prism spacing token.
///
/// `EdgeInsets.all(16)` and `SizedBox(height: 24)` are the two ways this shows
/// up in practice, and both have a token equivalent, so both are reported with
/// the token named.
///
/// A value with no token equivalent — `13`, `7` — is left alone. Reporting those
/// would train people to ignore the rule, and there is nothing actionable to say.
class HardcodedSpacing extends DartLintRule {
  /// Creates the rule.
  const HardcodedSpacing() : super(code: _code);

  static const _code = LintCode(
    name: 'hardcoded_spacing',
    problemMessage:
        'This spacing value matches a Prism token, so it can be expressed as '
        'one.',
    correctionMessage:
        'Use context.prismTokens (the token here is {0}), so the value follows '
        'the design system instead of being fixed at this call site.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final className = createdClassName(node);
      final arguments = node.argumentList;

      if (className == 'SizedBox') {
        _checkNamed(reporter, arguments, 'height');
        _checkNamed(reporter, arguments, 'width');
        return;
      }

      if (className != 'EdgeInsets') return;

      switch (createdConstructorName(node)) {
        case 'all':
          _report(reporter, positionalArgument(arguments, 0));
        case 'symmetric':
          _checkNamed(reporter, arguments, 'horizontal');
          _checkNamed(reporter, arguments, 'vertical');
        case 'only':
          for (final side in const [
            'left',
            'top',
            'right',
            'bottom',
          ]) {
            _checkNamed(reporter, arguments, side);
          }
        case 'fromLTRB':
          for (var i = 0; i < 4; i++) {
            _report(reporter, positionalArgument(arguments, i));
          }
      }
    });
  }

  void _checkNamed(
          DiagnosticReporter reporter, ArgumentList arguments, String name) =>
      _report(reporter, namedArgumentValue(arguments, name));

  void _report(DiagnosticReporter reporter, Expression? expression) {
    final value = numericLiteral(expression);
    if (value == null) return;
    final token = PrismTokenValues.spacing[value];
    if (token == null) return;
    reporter.atNode(expression!, _code, arguments: [token]);
  }
}

/// Flags a corner radius that duplicates a Prism radius token.
///
/// Only `BorderRadius.circular(N)` is checked. `BorderRadius.all(Radius.elliptical(…))`
/// is used for deliberate shapes rather than token-shaped ones, so it is not
/// worth the noise.
class HardcodedRadius extends DartLintRule {
  /// Creates the rule.
  const HardcodedRadius() : super(code: _code);

  static const _code = LintCode(
    name: 'hardcoded_radius',
    problemMessage: 'This radius matches a Prism token.',
    correctionMessage: 'Use context.prismTokens.{0} instead of a fixed radius.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (createdClassName(node) != 'BorderRadius') return;
      if (createdConstructorName(node) != 'circular') return;

      final expression = positionalArgument(node.argumentList, 0);
      final value = numericLiteral(expression);
      if (value == null) return;
      final token = PrismTokenValues.radii[value];
      if (token == null) return;
      reporter.atNode(expression!, _code, arguments: [token]);
    });
  }
}

/// Flags a duration that duplicates a Prism motion token.
///
/// Distinct from [PreferPrismMotion], which owns the `duration:` argument of an
/// animated widget because there the problem is reduced motion rather than
/// naming. This rule covers every other Duration literal, and deliberately stays
/// silent in that position so a single line never produces two warnings with the
/// same fix.
class HardcodedDuration extends DartLintRule {
  /// Creates the rule.
  const HardcodedDuration() : super(code: _code);

  static const _code = LintCode(
    name: 'hardcoded_duration',
    problemMessage: 'This duration matches a Prism motion token.',
    correctionMessage:
        'Use context.prismMotion(context.prismTokens.{0}), which also honours '
        'the platform reduce-motion setting.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (createdClassName(node) != 'Duration') return;

      for (final unit in const ['milliseconds', 'microseconds']) {
        final expression = namedArgumentValue(node.argumentList, unit);
        final value = numericLiteral(expression);
        if (value == null) continue;

        final millis = unit == 'milliseconds' ? value : value / 1000;
        final token = PrismTokenValues.durations[millis];
        if (token == null) continue;
        // Animated widgets are prefer_prism_motion's case, which carries the
        // stronger message about reduced motion.
        if (isAnimatedWidgetDuration(expression!)) continue;
        reporter.atNode(expression, _code, arguments: [token]);
      }
    });
  }
}

/// Flags a hard-coded animation duration on a widget that should honour the
/// platform's reduce-motion setting.
///
/// This is the one rule here that reports a defect rather than a preference: an
/// `AnimatedContainer` with a literal duration animates for a user who has asked
/// the platform for less motion. Wrapping the value in `context.prismMotion(…)`
/// collapses it to zero in that case.
class PreferPrismMotion extends DartLintRule {
  /// Creates the rule.
  const PreferPrismMotion() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_prism_motion',
    problemMessage:
        'This animation will run even when the platform asks for reduced motion.',
    correctionMessage:
        'Wrap the duration in context.prismMotion(…), which returns '
        'Duration.zero when animations are disabled.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final className = createdClassName(node);
      if (className == null) return;
      if (!PrismTokenValues.animatedWidgets.contains(className)) return;

      final expression = namedArgumentValue(node.argumentList, 'duration');
      if (expression == null) return;

      // Already wrapped in prismMotion: nothing to say.
      if (_isPrismMotion(expression)) return;
      // A reference to a named constant is the caller's decision to make.
      if (expression is! InstanceCreationExpression) return;
      if (createdClassName(expression) != 'Duration') return;

      reporter.atNode(expression, _code);
    });
  }

  bool _isPrismMotion(Expression expression) {
    if (expression is MethodInvocation) {
      return expression.methodName.name == 'prismMotion';
    }
    if (expression is PropertyAccess) {
      return expression.propertyName.name == 'prismMotion';
    }
    return false;
  }
}

/// Flags a colour literal that is one of Prism's fixed semantic colours.
///
/// Narrow on purpose. A raw `Color(0xFF…)` is usually deliberate — a brand
/// colour, a gradient stop — and reporting all of them would be unusable. The
/// only case worth catching is a hex that was copied out of Prism, because then
/// the app has frozen a value the design system is supposed to own.
class HardcodedSemanticColor extends DartLintRule {
  /// Creates the rule.
  const HardcodedSemanticColor() : super(code: _code);

  static const _code = LintCode(
    name: 'hardcoded_semantic_color',
    problemMessage: 'This colour is one of Prism\'s fixed semantic colours.',
    correctionMessage:
        'This is {0}. Use context.prismColors.forRole(...) instead, so light and '
        'dark resolve correctly.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (createdClassName(node) != 'Color') return;

      final expression = positionalArgument(node.argumentList, 0);
      final value = numericLiteral(expression);
      if (value == null) return;

      final role = PrismTokenValues.colors[value.toInt()];
      if (role == null) return;
      reporter.atNode(expression!, _code, arguments: [role]);
    });
  }
}
