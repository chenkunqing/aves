import 'dart:async';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/props.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/analysis_controller.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/face.dart';
import 'package:aves/model/source/location/location.dart';
import 'package:aves/model/source/tag.dart';
import 'package:aves/services/analysis_service.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/widgets/aves_app.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

class AnalysisOrchestrator {
  final CollectionSource source;

  static const _serviceThresholds = (catalog: 400, faces: 200, places: 200);

  AnalysisOrchestrator(this.source);

  Future<void> analyze(AnalysisController? analysisController, {Set<AvesEntry>? entries}) async {
    final todoEntries = entries ?? source.allEntries;
    final defaultAnalysisController = AnalysisController();
    final controller = analysisController ?? defaultAnalysisController;
    final force = controller.force;
    if (!controller.isStopping) {
      var startAnalysisService = false;
      if (controller.canStartService && settings.canUseAnalysisService) {
        if (!startAnalysisService) {
          final opCount = (force ? todoEntries : todoEntries.where(TagMixin.catalogEntriesTest)).length;
          startAnalysisService = opCount > _serviceThresholds.catalog;
        }
        if (!startAnalysisService) {
          final opCount = (force ? todoEntries.where((entry) => entry.isImage) : todoEntries.where(FaceMixin.faceDetectionTest)).length;
          startAnalysisService = opCount > _serviceThresholds.faces;
        }
        if (!startAnalysisService && await availability.canLocatePlaces) {
          final opCount = (force ? todoEntries.where((entry) => entry.hasGps) : todoEntries.where(LocationMixin.locatePlacesTest)).length;
          startAnalysisService = opCount > _serviceThresholds.places;
        }
      }

      debugPrint('analyze ${todoEntries.length} entries, force=$force, starting service=$startAnalysisService');
      if (startAnalysisService) {
        final lifecycleState = AvesApp.lifecycleStateNotifier.value;
        switch (lifecycleState) {
          case AppLifecycleState.resumed:
          case AppLifecycleState.inactive:
            await AnalysisService.startService(
              force: force,
              entryIds: entries?.map((entry) => entry.id).toList(),
            );
          default:
            unawaited(reportService.log('analysis service not started because app is in state=$lifecycleState'));
        }
      } else {
        await deviceService.requestGarbageCollection();
        await source.catalogEntries(controller, todoEntries);
        source.updateDerivedFilters(todoEntries);
        await source.locateEntries(controller, todoEntries);
        source.updateDerivedFilters(todoEntries);
        await source.detectFaces(controller, todoEntries);
      }
    }
    defaultAnalysisController.dispose();
    source.state = SourceState.ready;
  }
}
