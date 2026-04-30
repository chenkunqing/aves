import 'package:aves/model/entry_faces.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/theme/icons.dart';
import 'package:flutter/widgets.dart';

class FaceCountFilter extends CollectionFilter {
  static const type = 'faceCount';
  static const int twoPersonCount = 2;
  static const int multiPersonMinCount = 3;

  final int minFaces;
  final int? maxFaces;
  late final EntryPredicate _test;

  @override
  List<Object?> get props => [minFaces, maxFaces, reversed];

  FaceCountFilter(
    this.minFaces, {
    this.maxFaces,
    super.reversed = false,
  }) {
    _test = (entry) {
      final faceCount = entryFaces.getFaceCount(entry.id) ?? 0;
      return faceCount >= minFaces && (maxFaces == null || faceCount <= maxFaces!);
    };
  }

  FaceCountFilter.twoPerson({super.reversed = false})
    : minFaces = twoPersonCount,
      maxFaces = twoPersonCount {
    _test = (entry) => (entryFaces.getFaceCount(entry.id) ?? 0) == twoPersonCount;
  }

  FaceCountFilter.multiPerson({super.reversed = false})
    : minFaces = multiPersonMinCount,
      maxFaces = null {
    _test = (entry) => (entryFaces.getFaceCount(entry.id) ?? 0) >= multiPersonMinCount;
  }

  bool get isTwoPersonFilter => minFaces == twoPersonCount && maxFaces == twoPersonCount;

  bool get isMultiPersonFilter => minFaces == multiPersonMinCount && maxFaces == null;

  bool get isGroupPhotoFilter => minFaces == twoPersonCount && maxFaces == null;

  factory FaceCountFilter.fromMap(Map<String, Object?> json) {
    return FaceCountFilter(
      json['minFaces'] as int? ?? 2,
      maxFaces: json['maxFaces'] as int?,
      reversed: json['reversed'] as bool? ?? false,
    );
  }

  @override
  Map<String, Object?> toMap() => {
    'type': type,
    'minFaces': minFaces,
    if (maxFaces != null) 'maxFaces': maxFaces,
    'reversed': reversed,
  };

  @override
  EntryPredicate get positiveTest => _test;

  @override
  bool get exclusiveProp => false;

  @override
  String get universalLabel {
    if (isTwoPersonFilter) return 'Two-person photos';
    if (isMultiPersonFilter) return 'Multi-person photos';
    if (isGroupPhotoFilter) return 'Group photos';
    if (maxFaces != null && minFaces == maxFaces) return '$minFaces-face photos';
    if (maxFaces != null) return '$minFaces-$maxFaces face photos';
    return '$minFaces+ face photos';
  }

  @override
  String getLabel(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode.startsWith('zh')) {
      if (isTwoPersonFilter) return '两人合影';
      if (isMultiPersonFilter) return '多人合影';
      if (isGroupPhotoFilter) return '合影';
      if (maxFaces != null && minFaces == maxFaces) return '$minFaces 人';
      if (maxFaces != null) return '$minFaces-$maxFaces 人';
      return '$minFaces+ 人';
    }
    return universalLabel;
  }

  @override
  Widget? iconBuilder(BuildContext context, double size, {bool allowGenericIcon = true}) {
    return Icon(AIcons.group, size: size);
  }

  @override
  String get category => type;

  @override
  String get key => '$type-$reversed-$minFaces-${maxFaces ?? "*"}';
}
