import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

class ColorUtils {
  // `Color(0x00FFFFFF)` is different from `Color(0x00000000)` (or `Colors.transparent`)
  // when used in gradients or lerping to it
  static const transparentWhite = Color(0x00FFFFFF);
  static const transparentBlack = Color(0x00000000);

  static Color textColorOn(Color background) {
    final l = luma(
      background.intRed,
      background.intGreen,
      background.intBlue,
    );
    return Color(l >= .5 ? 0xFF000000 : 0xFFFFFFFF);
  }

  // quick computation of luma (Y component of YUV or YIQ) from RGB
  // cf https://en.wikipedia.org/wiki/Y%E2%80%B2UV
  // cf https://en.wikipedia.org/wiki/YIQ
  // `Color.computeLuminance()` is more accurate, but slower
  // r, g, b in [0, 255], luma in [0, 1]
  static double luma(int r, int g, int b) {
    return (r * .299 + g * .587 + b * .114) / 255;
  }
}

class ColorMatcher {
  static const double _neutralChromaThreshold = 15;
  static const double _hueTolerance = 30;
  static const double _toneTolerance = 35;
  static const double _neutralToneTolerance = 20;

  static bool isMatch(int argb1, int argb2) {
    final hct1 = Hct.fromInt(argb1);
    final hct2 = Hct.fromInt(argb2);

    final isNeutral1 = hct1.chroma < _neutralChromaThreshold;
    final isNeutral2 = hct2.chroma < _neutralChromaThreshold;

    if (isNeutral1 && isNeutral2) {
      return (hct1.tone - hct2.tone).abs() <= _neutralToneTolerance;
    }
    if (isNeutral1 != isNeutral2) return false;

    final hueDiff = _circularDistance(hct1.hue, hct2.hue, 360);
    final toneDiff = (hct1.tone - hct2.tone).abs();
    return hueDiff <= _hueTolerance && toneDiff <= _toneTolerance;
  }

  static double _circularDistance(double a, double b, double period) {
    final diff = (a - b).abs();
    return math.min(diff, period - diff);
  }
}

extension ExtraColor on Color {
  int get intRed => (r * 255).round(); // sRGB red component
  int get intGreen => (g * 255).round(); // sRGB green component
  int get intBlue => (b * 255).round(); // sRGB blue component

  // serialization

  String toJson() => jsonEncode(_toMap());

  static Color? fromJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;

    try {
      final jsonMap = jsonDecode(jsonString);
      if (jsonMap is Map<String, Object?>) {
        return _fromMap(jsonMap);
      }
      debugPrint('failed to parse color from json=$jsonString');
    } catch (error, stack) {
      debugPrint('failed to parse color from json=$jsonString error=$error\n$stack');
    }
    return null;
  }

  Map<String, Object?> _toMap() => {
    'a': a,
    'r': r,
    'g': g,
    'b': b,
    'colorSpace': colorSpace.name,
  };

  static Color _fromMap(Map<String, Object?> map) {
    return Color.from(
      alpha: map['a'] as double,
      red: map['r'] as double,
      green: map['g'] as double,
      blue: map['b'] as double,
      colorSpace: ColorSpace.values.byName(map['colorSpace'] as String),
    );
  }
}
