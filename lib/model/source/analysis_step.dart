import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/source/batch_processor.dart';
import 'package:aves_model/aves_model.dart';

class AnalysisStep {
  final BatchProcessor batch;
  final bool Function(AvesEntry entry) testPredicate;
  final bool Function(AvesEntry entry)? forceFilter;
  final SourceState sourceState;

  const AnalysisStep({
    required this.batch,
    required this.testPredicate,
    this.forceFilter,
    required this.sourceState,
  });
}
