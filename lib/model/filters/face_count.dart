import 'package:aves/model/entry_faces.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/theme/icons.dart';
import 'package:flutter/widgets.dart';

class FaceCountFilter extends CollectionFilter {
  static const type = 'faceCount';

  final int minFaces;
  late final EntryPredicate _test;

  @override
  List<Object?> get props => [minFaces, reversed];

  FaceCountFilter(this.minFaces, {super.reversed = false}) {
    _test = (entry) => (entryFaces.getFaceCount(entry.id) ?? 0) >= minFaces;
  }

  factory FaceCountFilter.fromMap(Map<String, Object?> json) {
    return FaceCountFilter(
      json['minFaces'] as int? ?? 2,
      reversed: json['reversed'] as bool? ?? false,
    );
  }

  @override
  Map<String, Object?> toMap() => {
    'type': type,
    'minFaces': minFaces,
    'reversed': reversed,
  };

  @override
  EntryPredicate get positiveTest => _test;

  @override
  bool get exclusiveProp => false;

  @override
  String get universalLabel => minFaces >= 2 ? '合照' : '$minFaces+ 人脸';

  @override
  String getLabel(BuildContext context) => universalLabel;

  @override
  Widget? iconBuilder(BuildContext context, double size, {bool allowGenericIcon = true}) {
    return Icon(AIcons.group, size: size);
  }

  @override
  String get category => type;

  @override
  String get key => '$type-$reversed-$minFaces';
}
