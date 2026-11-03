// Fixture for verifying prism_lints. Each `// LINT` comment marks a line that
// should be reported; the values below it must NOT be.
import 'package:flutter/material.dart';

Widget paddingViolations() {
  return Padding(
    padding: EdgeInsets.all(16), // LINT hardcoded_spacing (spaceMd)
    child: SizedBox(
      height: 24, // LINT hardcoded_spacing (spaceLg)
      child: const Text('hi'),
    ),
  );
}

Widget radiusViolation() {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12), // LINT hardcoded_radius (radiusMd)
    ),
  );
}

Widget durationViolation() {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 240), // LINT hardcoded_duration
    child: const SizedBox.shrink(),
  );
}

Widget motionViolation() {
  return AnimatedOpacity(
    duration: const Duration(milliseconds: 350), // LINT prefer_prism_motion
    opacity: 0.5,
    child: const SizedBox.shrink(),
  );
}

Widget colourViolation() {
  return const ColoredBox(
    color: Color(0xFF1B7A4B), // LINT hardcoded_semantic_color
  );
}

// ---- None of the following should be reported ----

Widget notFlaggedOffTokenValues() {
  return Padding(
    padding: EdgeInsets.all(13), // no token is 13
    child: SizedBox(
      height: 7, // no token is 7
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6), // no token is 6
        ),
      ),
    ),
  );
}

Widget notFlaggedDynamic() {
  final gap = 16;
  return SizedBox(height: gap); // not a literal
}

Widget alreadyCorrect(BuildContext context) {
  return AnimatedOpacity(
    duration: context.prismMotion(const Duration(milliseconds: 350)), // wrapped
    opacity: 0.5,
    child: Padding(
      padding: EdgeInsets.all(context.prismTokens.spaceMd), // uses the token
      child: const SizedBox.shrink(),
    ),
  );
}
