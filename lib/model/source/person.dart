import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/filters/person.dart';
import 'package:aves/model/source/analysis_controller.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves_model/aves_model.dart';

mixin PersonMixin on SourceBase {
  List<int> sortedPersonIds = List.unmodifiable([]);

  Future<void> loadPersonData() async {}

  Future<void> clusterFaces(AnalysisController controller) async {}

  void updatePersons() {}

  void invalidatePersonFilterSummary({Set<AvesEntry>? entries, bool notify = true}) {}

  int personEntryCount(PersonFilter filter) => 0;

  int personSize(PersonFilter filter) => 0;

  AvesEntry? personRecentEntry(PersonFilter filter) => null;
}

class PersonsChangedEvent {}

class PersonSummaryInvalidatedEvent {
  const PersonSummaryInvalidatedEvent();
}
