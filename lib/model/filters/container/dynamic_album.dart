import 'package:aves/model/filters/container/album_group.dart';
import 'package:aves/model/filters/container/container.dart';
import 'package:aves/model/filters/covered/covered.dart';
import 'package:aves/model/filters/face_count.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/theme/icons.dart';
import 'package:flutter/widgets.dart';

// a dynamic album can act as:
// - an alias, when inner filter is a simple filter,
// - a combination, when inner filter is a container.
class DynamicAlbumFilter extends CollectionFilter with ContainerFilter, CoveredFilter, AlbumBaseFilter {
  static const type = 'dynamic_album';
  static const twoPersonBuiltInName = '__aves_builtin_two_person_group__';
  static const multiPersonBuiltInName = '__aves_builtin_multi_person_group__';

  final String name;
  final CollectionFilter filter;

  @override
  List<Object?> get props => [name, filter, reversed];

  DynamicAlbumFilter(this.name, this.filter, {super.reversed = false});

  static DynamicAlbumFilter get twoPersonBuiltIn => DynamicAlbumFilter(
    twoPersonBuiltInName,
    FaceCountFilter.twoPerson(),
  );

  static DynamicAlbumFilter get multiPersonBuiltIn => DynamicAlbumFilter(
    multiPersonBuiltInName,
    FaceCountFilter.multiPerson(),
  );

  bool get isBuiltIn => name == twoPersonBuiltInName || name == multiPersonBuiltInName;

  static DynamicAlbumFilter? fromMap(Map<String, Object?> json) {
    final filter = CollectionFilter.fromJson(json['filter'] as String?);
    if (filter == null) return null;

    return DynamicAlbumFilter(
      json['name'] as String,
      filter,
      reversed: json['reversed'] as bool? ?? false,
    );
  }

  @override
  Map<String, Object?> toMap() => {
    'type': type,
    'name': name,
    'filter': filter.toJson(),
    'reversed': reversed,
  };

  @override
  EntryPredicate get positiveTest => filter.test;

  @override
  bool get exclusiveProp => false;

  @override
  String get universalLabel => switch (name) {
    twoPersonBuiltInName => 'Two-person photos',
    multiPersonBuiltInName => 'Multi-person photos',
    _ => name,
  };

  @override
  String getLabel(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode.startsWith('zh')) {
      return switch (name) {
        twoPersonBuiltInName => '两人合影',
        multiPersonBuiltInName => '多人合影',
        _ => name,
      };
    }
    return universalLabel;
  }

  @override
  Widget? iconBuilder(BuildContext context, double size, {bool allowGenericIcon = true}) {
    return allowGenericIcon ? Icon(AIcons.dynamicAlbum, size: size) : null;
  }

  @override
  String get category => type;

  @override
  String get key => '$type-$reversed-$name';

  // container

  @override
  Set<CollectionFilter> get innerFilters => {filter};

  @override
  DynamicAlbumFilter? replaceFilters(CollectionFilter? Function(CollectionFilter oldFilter) toElement) {
    final newFilter = toElement(filter);
    return newFilter != null
        ? DynamicAlbumFilter(
            name,
            newFilter,
            reversed: reversed,
          )
        : null;
  }
}
