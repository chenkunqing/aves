import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:streams_channel/streams_channel.dart';

const bool debugAvesPlatformChannels = kDebugMode || kProfileMode;

class AvesMethodChannel extends MethodChannel {
  const AvesMethodChannel(super.name);

  @override
  Future<T?> invokeMethod<T>(String method, [arguments]) {
    if (debugAvesPlatformChannels) {
      debugPrint('$runtimeType platform call isolate=${Isolate.current.debugName} channel=$name method=$method arguments=$arguments');
    }
    return super.invokeMethod(method, arguments);
  }
}

class AvesStreamsChannel extends StreamsChannel {
  AvesStreamsChannel(super.name);

  @override
  Stream receiveBroadcastStream([arguments]) {
    if (debugAvesPlatformChannels) {
      debugPrint('$runtimeType platform call isolate=${Isolate.current.debugName} channel=$name arguments=$arguments');
    }
    return super.receiveBroadcastStream(arguments);
  }
}
