import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/person.dart';
import 'package:aves/theme/icons.dart';
import 'package:flutter/widgets.dart';

class PersonFilter extends CollectionFilter {
  static const type = 'person';

  final int personId;
  final String? displayName;
  late final EntryPredicate _test;

  @override
  List<Object?> get props => [personId, reversed];

  PersonFilter(this.personId, {this.displayName, super.reversed = false}) {
    _test = (entry) => personStore.getPersonsForEntry(entry.id).contains(personId);
  }

  factory PersonFilter.fromMap(Map<String, Object?> json) {
    return PersonFilter(
      json['personId'] as int,
      displayName: json['displayName'] as String?,
      reversed: json['reversed'] as bool? ?? false,
    );
  }

  @override
  Map<String, Object?> toMap() => {
        'type': type,
        'personId': personId,
        'displayName': displayName,
        'reversed': reversed,
      };

  @override
  EntryPredicate get positiveTest => _test;

  @override
  bool get exclusiveProp => false;

  @override
  String get universalLabel => displayName ?? personStore.getById(personId)?.name ?? '人物 $personId';

  @override
  String getLabel(BuildContext context) => universalLabel;

  @override
  Widget? iconBuilder(BuildContext context, double size, {bool allowGenericIcon = true}) {
    return allowGenericIcon ? Icon(AIcons.person, size: size) : null;
  }

  @override
  String get category => type;

  @override
  String get key => '$type-$reversed-$personId';
}
