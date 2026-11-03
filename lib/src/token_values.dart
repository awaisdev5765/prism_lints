import 'package:analyzer/dart/ast/ast.dart';

/// The default Prism token values, and the names they map to.
///
/// Every rule in this package follows one principle: **flag a literal only when
/// it exactly duplicates a token**. A value like `13` has no token equivalent, so
/// flagging it would be noise the user cannot act on. A value like `16` does have
/// one, so the rule can name it.
///
/// That single constraint is what keeps these rules quiet enough to leave enabled
/// by default, which matters because custom_lint turns every rule in a plugin on
/// unless the user opts out.
///
/// If you override the defaults in `ThemeData.extensions`, the numbers here are
/// still the right ones to flag: a hard-coded `16` is hard-coded either way. The
/// suggestion text says which token it corresponds to in the defaults.
abstract final class PrismTokenValues {
  /// `PrismTokens.space*`, by value.
  static const spacing = <num, String>{
    4: 'spaceXs',
    8: 'spaceSm',
    16: 'spaceMd',
    24: 'spaceLg',
    32: 'spaceXl',
    48: 'spaceXxl',
  };

  /// `PrismTokens.radius*`, by value.
  static const radii = <num, String>{
    8: 'radiusSm',
    12: 'radiusMd',
    16: 'radiusLg',
    24: 'radiusXl',
  };

  /// `PrismTokens.duration*`, in milliseconds.
  static const durations = <num, String>{
    120: 'durationFast',
    240: 'durationMedium',
    420: 'durationSlow',
  };

  /// The fixed Prism semantic colours, by ARGB value.
  ///
  /// Only `success` and `warning` are fixed; `error` and `info` come from the
  /// app's own `ColorScheme`, so there is no constant to compare against and a
  /// copied hex is the only case worth catching.
  static const colors = <int, String>{
    0xFF1B7A4B: 'PrismSemantic.success (light accent)',
    0xFF7BD8A8: 'PrismSemantic.success (dark accent)',
    0xFFC9F2DC: 'PrismSemantic.success container (light)',
    0xFF1E4C33: 'PrismSemantic.success container (dark)',
    0xFF8A5A00: 'PrismSemantic.warning (light accent)',
    0xFFFFCF6B: 'PrismSemantic.warning (dark accent)',
    0xFFFFE7B8: 'PrismSemantic.warning container (light)',
    0xFF54401A: 'PrismSemantic.warning container (dark)',
  };

  /// Widgets whose `duration:` argument should come from `context.prismMotion`.
  ///
  /// A hard-coded duration here is a real accessibility defect rather than a
  /// style preference: the widget will animate even when the platform asks for
  /// reduced motion.
  static const animatedWidgets = <String>{
    'AnimatedAlign',
    'AnimatedContainer',
    'AnimatedCrossFade',
    'AnimatedDefaultTextStyle',
    'AnimatedOpacity',
    'AnimatedPadding',
    'AnimatedPositioned',
    'AnimatedPositionedDirectional',
    'AnimatedRotation',
    'AnimatedScale',
    'AnimatedSize',
    'AnimatedSlide',
    'AnimatedSwitcher',
    'TweenAnimationBuilder',
  };
}

/// Reads a compile-time numeric literal, including a negated one.
///
/// Returns null for anything else — a variable, a constant, an expression — since
/// only literals are the user's own hard-coded value.
num? numericLiteral(Expression? expression) {
  if (expression == null) return null;
  if (expression is IntegerLiteral) return expression.value;
  if (expression is DoubleLiteral) return expression.value;
  if (expression is PrefixExpression &&
      expression.operator.lexeme == '-' &&
      expression.operand is IntegerLiteral) {
    return -(expression.operand as IntegerLiteral).value!;
  }
  return null;
}

/// The class name of an instance creation, e.g. `EdgeInsets` or `Duration`.
///
/// Resolves through the element, which is the reliable path and the one these
/// rules depend on: custom_lint analyses resolved units, so `type.element` is
/// populated for real Flutter types.
///
/// The written name is a fallback for the unresolved case, and it is only sound
/// when there is no ambiguity. Parsed without resolution, `EdgeInsets.all(16)`
/// comes back as `importPrefix: 'EdgeInsets', type.name: 'all'` -- identical in
/// shape to the genuinely prefixed `e.PrismBanner()` (`importPrefix: 'e',
/// type.name: 'PrismBanner'`). Nothing in the syntax distinguishes a constructor
/// on a class from a class behind a prefix until resolution decides, so a rule
/// that had to work unresolved would need a different strategy entirely.
///
/// Verified end to end against resolved code in `example/`, which is why the
/// unit tests for the dotted form live there rather than in `test/`.
String? createdClassName(InstanceCreationExpression node) {
  final element = node.constructorName.type.element;
  final fromElement = element?.name;
  if (fromElement != null) return fromElement;
  // Unresolved: prefer the constructor name when the parser separated it, which
  // is the prefixed form, otherwise take the written name.
  final explicit = node.constructorName.name;
  if (explicit != null) return node.constructorName.type.name.lexeme;
  return node.constructorName.type.name.lexeme;
}

/// The constructor name, e.g. `all` in `EdgeInsets.all(16)`.
String? createdConstructorName(InstanceCreationExpression node) =>
    node.constructorName.name?.name;

/// The expression bound to a named argument, e.g. `16` for `height: 16`.
Expression? namedArgumentValue(ArgumentList arguments, String name) {
  for (final argument in arguments.arguments) {
    if (argument is NamedExpression && argument.name.label.name == name) {
      return argument.expression;
    }
  }
  return null;
}

/// Whether [expression] is the `duration:` argument of an animated widget.
///
/// Used to keep HardcodedDuration off the ground PreferPrismMotion already
/// covers: both would report the same span, and two warnings on one line with the
/// same fix is noise rather than thoroughness.
bool isAnimatedWidgetDuration(Expression expression) {
  // Walk up to the enclosing `duration:` argument rather than looking at the
  // immediate parent. For `duration: Duration(milliseconds: 240)` the literal's
  // parent is `milliseconds:`, so a single-level check never matches.
  AstNode? node = expression;
  for (var depth = 0; node != null && depth < 6; depth++) {
    if (node is NamedExpression && node.name.label.name == 'duration') {
      final arguments = node.parent;
      if (arguments is! ArgumentList) return false;
      final creation = arguments.parent;
      if (creation is! InstanceCreationExpression) return false;
      final className = createdClassName(creation);
      return className != null &&
          PrismTokenValues.animatedWidgets.contains(className);
    }
    node = node.parent;
  }
  return false;
}

/// The positional argument at [index], or null.
Expression? positionalArgument(ArgumentList arguments, int index) {
  final positional =
      arguments.arguments.whereType<Expression>().toList(growable: false);
  if (index >= positional.length) return null;
  return positional[index];
}
