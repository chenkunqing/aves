import 'package:aves/model/filters/covered/stored_album.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/widgets/common/action_mixins/feedback.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/material.dart';

mixin VaultAwareMixin on FeedbackMixin {
  Future<bool> _tryUnlock(BuildContext context, String dirPath) async => true;

  Future<bool> unlockAlbum(BuildContext context, String dirPath) async {
    final success = await _tryUnlock(context, dirPath);
    if (!success) {
      showFeedback(context, FeedbackType.warn, context.l10n.genericFailureFeedback);
    }
    return success;
  }

  Future<bool> unlockFilter(BuildContext context, CollectionFilter filter) {
    return filter is StoredAlbumFilter ? unlockAlbum(context, filter.album) : Future.value(true);
  }

  Future<bool> unlockFilters(BuildContext context, Set<CollectionFilter> filters) async {
    var unlocked = true;
    await Future.forEach(filters, (filter) async {
      if (unlocked) {
        unlocked = await unlockFilter(context, filter);
      }
    });
    return unlocked;
  }

  void lockFilters(Set<CollectionFilter> filters) {}
}
