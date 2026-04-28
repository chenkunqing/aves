import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/filters/query.dart';
import 'package:aves/ref/unicode.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/widgets.dart';

class AspectRatioFilter extends CollectionFilter {
  static const type = 'aspect_ratio';

  final double threshold;
  final String op;
  final double tolerance;
  final String? ratioText;
  late final EntryPredicate _test;

  static final landscape = AspectRatioFilter(1, QueryFilter.opGreater);
  static final portrait = AspectRatioFilter(1, QueryFilter.opLower);
  static final ratio4x3 = AspectRatioFilter(4 / 3, QueryFilter.opEqual, tolerance: 0.03, ratioText: '4${UniChars.ratio}3');
  static final ratio16x9 = AspectRatioFilter(16 / 9, QueryFilter.opEqual, tolerance: 0.03, ratioText: '16${UniChars.ratio}9');
  static final ratio1x1 = AspectRatioFilter(1, QueryFilter.opEqual, tolerance: 0.03, ratioText: '1${UniChars.ratio}1');
  static final customPrompt = AspectRatioFilter(0, QueryFilter.opEqual);

  @override
  List<Object?> get props => [threshold, op, tolerance, ratioText, reversed];

  AspectRatioFilter(this.threshold, this.op, {this.tolerance = 0, this.ratioText, super.reversed = false}) {
    switch (op) {
      case QueryFilter.opEqual:
        if (tolerance > 0) {
          final lo = threshold - tolerance;
          final hi = threshold + tolerance;
          _test = (entry) {
            final r = entry.displayAspectRatio;
            return r >= lo && r <= hi;
          };
        } else {
          _test = (entry) => entry.displayAspectRatio == threshold;
        }
      case QueryFilter.opLower:
        _test = (entry) => entry.displayAspectRatio < threshold;
      case QueryFilter.opGreater:
        _test = (entry) => entry.displayAspectRatio > threshold;
    }
  }

  factory AspectRatioFilter.fromMap(Map<String, Object?> json) {
    return AspectRatioFilter(
      json['threshold'] as double,
      json['op'] as String,
      tolerance: (json['tolerance'] as num?)?.toDouble() ?? 0,
      ratioText: json['ratioText'] as String?,
      reversed: json['reversed'] as bool? ?? false,
    );
  }

  @override
  Map<String, Object?> toMap() => {
    'type': type,
    'threshold': threshold,
    'op': op,
    if (tolerance > 0) 'tolerance': tolerance,
    if (ratioText != null) 'ratioText': ratioText,
    'reversed': reversed,
  };

  @override
  EntryPredicate get positiveTest => _test;

  @override
  bool get exclusiveProp => true;

  bool get isCustomPrompt => this == customPrompt;

  @override
  String get universalLabel {
    if (isCustomPrompt) return 'Custom ratio';
    final display = ratioText ?? formatNumber(threshold);
    if (tolerance > 0) return '$display ±${formatNumber(tolerance)}';
    return '$op $display';
  }

  bool get isPredefinedRatio => this == ratio4x3 || this == ratio16x9 || this == ratio1x1;

  @override
  String getLabel(BuildContext context) {
    if (isCustomPrompt) {
      return context.locale.startsWith('zh') ? '自定义比例…' : 'Custom ratio…';
    }
    final l10n = context.l10n;
    if (threshold == 1 && tolerance == 0) {
      switch (op) {
        case QueryFilter.opGreater:
          return l10n.filterAspectRatioLandscapeLabel;
        case QueryFilter.opLower:
          return l10n.filterAspectRatioPortraitLabel;
      }
    }
    if (isPredefinedRatio && ratioText != null) {
      return ratioText!;
    }
    return universalLabel;
  }

  @override
  Widget? iconBuilder(BuildContext context, double size, {bool allowGenericIcon = true}) => Icon(AIcons.aspectRatio, size: size);

  @override
  String get category => type;

  @override
  String get key => '$type-$reversed-$threshold-$op-$tolerance';

  static (double, String)? tryParseRatio(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    // "3:4" or "3∶4"
    for (final sep in [':', UniChars.ratio]) {
      if (s.contains(sep)) {
        final parts = s.split(sep);
        if (parts.length != 2) return null;
        final a = double.tryParse(parts[0].trim());
        final b = double.tryParse(parts[1].trim());
        if (a == null || b == null || b == 0) return null;
        return (a / b, '${parts[0].trim()}${UniChars.ratio}${parts[1].trim()}');
      }
    }

    // "4/3"
    if (s.contains('/')) {
      final parts = s.split('/');
      if (parts.length != 2) return null;
      final a = double.tryParse(parts[0].trim());
      final b = double.tryParse(parts[1].trim());
      if (a == null || b == null || b == 0) return null;
      return (a / b, s);
    }

    // plain number "0.75"
    final v = double.tryParse(s);
    if (v == null || v <= 0) return null;
    return (v, s);
  }

  static String formatNumber(double value) {
    final s = value.toStringAsFixed(4);
    // trim trailing zeros but keep at least one decimal
    final trimmed = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }
}
