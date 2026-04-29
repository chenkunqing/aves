import 'package:aves/model/entry_colors.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/widgets/common/basic/color_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class ColorFilter extends CollectionFilter {
  static const type = 'color';

  final int colorValue;
  late final EntryPredicate _test;

  @override
  List<Object?> get props => [colorValue, reversed];

  ColorFilter(this.colorValue, {super.reversed = false}) {
    final matchingIds = entryColors.getMatchingEntryIds(colorValue);
    _test = (entry) => matchingIds.contains(entry.id);
  }

  factory ColorFilter.fromMap(Map<String, Object?> json) {
    return ColorFilter(
      json['colorValue'] as int,
      reversed: json['reversed'] as bool? ?? false,
    );
  }

  @override
  Map<String, Object?> toMap() => {
        'type': type,
        'colorValue': colorValue,
        'reversed': reversed,
      };

  @override
  EntryPredicate get positiveTest => _test;

  @override
  bool get exclusiveProp => false;

  @override
  String get universalLabel => '#$_hexString';

  String get _hexString {
    final c = Color(colorValue);
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '$r$g$b'.toUpperCase();
  }

  @override
  Widget? iconBuilder(BuildContext context, double size, {bool allowGenericIcon = true}) {
    return ColorIndicator(value: Color(colorValue));
  }

  @override
  Future<Color> color(BuildContext context) {
    return SynchronousFuture(Color(colorValue));
  }

  @override
  String get category => type;

  @override
  String get key => '$type-$reversed-$colorValue';
}
