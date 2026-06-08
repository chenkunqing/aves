import 'package:aves_utils/aves_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class SlowMotionRange {
  final double start, end; // in [0, 1]

  SlowMotionRange({
    required double start,
    required double end,
  }) : start = start.clamp(0, 1),
       end = end.clamp(0, 1);

  SlowMotionRange sanitize() {
    if (start > end) {
      return SlowMotionRange(start: end, end: start);
    }
    return SlowMotionRange(start: start, end: end);
  }

  bool inRange(double progress) => start < progress && progress < end;
}

mixin SlowMotionMixin on Disposer {
  double slowMotionFactor = 1;

  ValueNotifier<SlowMotionRange> slowMotionRangeNotifier = ValueNotifier(SlowMotionRange(start: .25, end: .75));

  @override
  void dispose() {
    slowMotionRangeNotifier.dispose();
    super.dispose();
  }

  void setSlowMotionStart(double start) => _setSlowMotion(SlowMotionRange(start: start, end: slowMotionRangeNotifier.value.end));

  void setSlowMotionEnd(double end) => _setSlowMotion(SlowMotionRange(start: slowMotionRangeNotifier.value.start, end: end));

  void _setSlowMotion(SlowMotionRange v) => slowMotionRangeNotifier.value = v.sanitize();
}
