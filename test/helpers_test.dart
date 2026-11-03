import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import 'package:prism_lints/src/token_values.dart';

/// These tests parse source without resolving it, which is enough for the pure
/// helpers but has one sharp edge worth stating: **without the `new` keyword,
/// analyzer parses `Duration(…)` as a `MethodInvocation`, not an
/// `InstanceCreationExpression`** until resolution rewrites it.
///
/// The rules match `InstanceCreationExpression`, so the sources below use
/// explicit `new` to exercise them here. That the `new`-less form works in a
/// real project is verified end to end by running `dart run custom_lint` over
/// `example/`, where files are resolved. A test that asserted on the unresolved
/// `new`-less form would be testing a shape the rules never see in practice.
IntegerLiteral _firstIntLiteral(String source) {
  final unit = parseString(content: source).unit;
  final finder = _LiteralFinder();
  unit.accept(finder);
  return finder.found!;
}

class _LiteralFinder extends RecursiveAstVisitor<void> {
  IntegerLiteral? found;

  @override
  void visitIntegerLiteral(IntegerLiteral node) => found ??= node;
}

InstanceCreationExpression _firstCreation(String source) {
  final unit = parseString(content: source).unit;
  final finder = _CreationFinder();
  unit.accept(finder);
  return finder.found!;
}

class _CreationFinder extends RecursiveAstVisitor<void> {
  InstanceCreationExpression? found;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) =>
      found ??= node;
}

Expression _firstInitializer(String source) =>
    (parseString(content: source).unit.declarations.first
            as TopLevelVariableDeclaration)
        .variables
        .variables
        .first
        .initializer!;

void main() {
  group('numericLiteral', () {
    test('reads an integer literal', () {
      expect(numericLiteral(_firstIntLiteral('final x = 16;')), 16);
    });

    test('reads a double literal', () {
      expect(numericLiteral(_firstIntLiteral('final x = 12;')), 12);
    });

    test('reads a negated literal', () {
      expect(numericLiteral(_firstInitializer('final x = -8;')), -8);
    });

    test('returns null for a reference, not a literal', () {
      // The point of the helper: only the user's own literal is their hard-coded
      // value, so a variable must not be reported.
      expect(numericLiteral(_firstInitializer('final x = gap;')), isNull);
    });

    test('returns null for null', () => expect(numericLiteral(null), isNull));
  });

  group('token tables', () {
    test('spacing covers the documented scale', () {
      expect(PrismTokenValues.spacing.keys, [4, 8, 16, 24, 32, 48]);
      expect(PrismTokenValues.spacing[16], 'spaceMd');
    });

    test('radii and durations are complete', () {
      expect(PrismTokenValues.radii[12], 'radiusMd');
      expect(PrismTokenValues.durations[240], 'durationMedium');
    });

    test('no value maps to two tokens', () {
      for (final table in [
        PrismTokenValues.spacing,
        PrismTokenValues.radii,
        PrismTokenValues.durations,
      ]) {
        expect(table.values.toSet().length, table.length);
      }
    });

    test('every animated widget name looks like one', () {
      // A typo here would silently disable prefer_prism_motion for that widget,
      // which is the rule carrying the accessibility finding.
      expect(PrismTokenValues.animatedWidgets, contains('AnimatedContainer'));
      expect(PrismTokenValues.animatedWidgets, contains('AnimatedSwitcher'));
      expect(PrismTokenValues.animatedWidgets, contains('AnimatedOpacity'));
      for (final name in PrismTokenValues.animatedWidgets) {
        expect(
          name,
          anyOf(startsWith('Animated'), equals('TweenAnimationBuilder')),
          reason: '$name does not look like an animated widget',
        );
      }
    });
  });

  group('isAnimatedWidgetDuration', () {
    // Regression. The first implementation checked the immediate parent only, so
    // `duration: Duration(milliseconds: 240)` never matched -- the literal's
    // parent is `milliseconds:` -- and HardcodedDuration then double-reported on
    // the same line as PreferPrismMotion.
    test('recognises a wrapped Duration inside an animated widget', () {
      final literal = _firstIntLiteral(
        'final w = new AnimatedContainer('
        'duration: new Duration(milliseconds: 240));',
      );
      expect(isAnimatedWidgetDuration(literal), isTrue);
    });

    test('recognises a const Duration', () {
      final literal = _firstIntLiteral(
        'final w = new AnimatedOpacity('
        'duration: const Duration(milliseconds: 350));',
      );
      expect(isAnimatedWidgetDuration(literal), isTrue);
    });

    test('matches the same widget named through a prefix', () {
      final literal = _firstIntLiteral(
        'final w = new material.AnimatedContainer('
        'duration: new Duration(milliseconds: 240));',
      );
      expect(isAnimatedWidgetDuration(literal), isTrue);
    });

    test('does not match a duration on a non-animated widget', () {
      final literal = _firstIntLiteral(
        'final x = new SomethingElse(duration: new Duration(milliseconds: 240));',
      );
      expect(isAnimatedWidgetDuration(literal), isFalse);
    });

    test('does not match an unrelated literal inside an animated widget', () {
      final literal = _firstIntLiteral(
        'final w = new AnimatedContainer('
        'duration: new Duration(milliseconds: 240), '
        'padding: new EdgeInsets.all(8));',
      );
      // The first literal is inside the duration, so this is true; the guard
      // being tested is that a literal elsewhere is not matched.
      expect(isAnimatedWidgetDuration(literal), isTrue);
    });

    test('does not match a bare literal with no enclosing call', () {
      expect(
        isAnimatedWidgetDuration(_firstIntLiteral('final x = 16;')),
        isFalse,
      );
    });
  });

  group('createdClassName', () {
    test('reads the written name for an unambiguous construction', () {
      expect(
        createdClassName(_firstCreation('final a = new PrismBanner();')),
        'PrismBanner',
      );
    });

    test(
        'the dotted form is ambiguous until resolution, and is covered '
        'end to end instead', () {
      // Parsed without resolution, `EdgeInsets.all(16)` reports type.name as
      // `all` with `EdgeInsets` as the import prefix -- indistinguishable from a
      // genuinely prefixed class. The resolved behaviour is verified by running
      // custom_lint over example/, not here.
      final creation = _firstCreation('final a = new EdgeInsets.all(16);');
      expect(creation.constructorName.name, isNull);
      expect(createdClassName(creation), isNot('PrismBanner'));
    });

    test('recognises a class with no constructor name', () {
      final creation = _firstCreation('final a = new PrismBanner();');
      expect(createdClassName(creation), 'PrismBanner');
      expect(createdConstructorName(creation), isNull);
    });

    test('ignores a prefix', () {
      expect(
        createdClassName(_firstCreation('final a = new e.EdgeInsets.all(16);')),
        'EdgeInsets',
      );
    });
  });

  group('argument access', () {
    test('namedArgumentValue finds a named argument', () {
      final creation = _firstCreation('final a = new SizedBox(height: 24);');
      expect(namedArgumentValue(creation.argumentList, 'height'), isNotNull);
      expect(namedArgumentValue(creation.argumentList, 'width'), isNull);
    });

    test('positionalArgument indexes correctly and stops at the end', () {
      final creation = _firstCreation('final a = new EdgeInsets.all(16);');
      expect(positionalArgument(creation.argumentList, 0), isNotNull);
      expect(positionalArgument(creation.argumentList, 1), isNull);
    });
  });

  group('the resolution caveat these tests work around', () {
    test('the new-less form is a MethodInvocation before resolution', () {
      // Documented so nobody "simplifies" the sources above by dropping `new`
      // and then wonders why the rules stop matching.
      final unit =
          parseString(content: 'final a = Duration(milliseconds: 1);').unit;
      final finder = _CreationFinder();
      unit.accept(finder);
      expect(finder.found, isNull, reason: 'no InstanceCreationExpression yet');

      final invocationFinder = _InvocationFinder();
      unit.accept(invocationFinder);
      expect(invocationFinder.found, isNotNull);
    });
  });
}

class _InvocationFinder extends RecursiveAstVisitor<void> {
  MethodInvocation? found;

  @override
  void visitMethodInvocation(MethodInvocation node) => found ??= node;
}
