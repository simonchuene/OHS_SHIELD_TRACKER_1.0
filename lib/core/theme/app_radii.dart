// path: lib/core/theme/app_radii.dart
import 'package:flutter/widgets.dart';

/// Non-uniform corner-radius system (Master Prompt Item 2). Deliberately NOT a
/// single radius — this is a first-class part of the design system.
abstract final class AppRadii {
  /// Standard card (CAPA, Risk, list): 12px uniform.
  static const double card = 12;

  /// Input fields: 12px.
  static const double input = 12;

  /// Primary CTA buttons: 16px (distinct from cards so buttons read as actionable).
  static const double button = 16;

  /// Hero/feature card top corners (Safety Score): 28px.
  static const double heroTop = 28;

  /// Hero/feature card bottom corners: 12px (asymmetric).
  static const double heroBottom = 12;

  /// Fully-rounded pills/chips.
  static const double pill = 999;

  /// Asymmetric hero card shape (Item 2 / 3a).
  static const BorderRadius heroCard = BorderRadius.only(
    topLeft: Radius.circular(heroTop),
    topRight: Radius.circular(heroTop),
    bottomLeft: Radius.circular(heroBottom),
    bottomRight: Radius.circular(heroBottom),
  );

  static const BorderRadius standardCard = BorderRadius.all(Radius.circular(card));
}
