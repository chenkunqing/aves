import 'dart:async';
import 'dart:isolate';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/services/common/channel.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves_utils/aves_utils.dart';
import 'package:aves_video/aves_video.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

abstract class MediaSessionService {
  Stream<MediaCommandEvent> get mediaCommands;

  Future<void> update({
    required AvesEntry entry,
    required AvesVideoController controller,
    required bool canSkipToNext,
    required bool canSkipToPrevious,
  });

  Future<void> release();
}

class PlatformMediaSessionService implements MediaSessionService, Disposable {
  static const _sessionChannel = AvesMethodChannel('deckers.thibault/aves/media_session');

  final Set<StreamSubscription> _subscriptions = {};
  final EventChannel _commandChannel = const OptionalEventChannel('deckers.thibault/aves/media_command');
  final StreamController _streamController = StreamController.broadcast();

  PlatformMediaSessionService() {
    _subscriptions.add(_commandChannel.receiveBroadcastStream().listen((event) => _onMediaCommand(event as Map?)));
  }

  @override
  void onDispose() {
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
  }

  @override
  Stream<MediaCommandEvent> get mediaCommands => _streamController.stream.where((event) => event is MediaCommandEvent).cast<MediaCommandEvent>();

  @override
  Future<void> update({
    required AvesEntry entry,
    required AvesVideoController controller,
    required bool canSkipToNext,
    required bool canSkipToPrevious,
  }) async {
    final args = <String, Object?>{
      'uri': entry.uri,
      'title': entry.bestTitle,
      'durationMillis': controller.duration,
      'state': _toPlatformState(controller.status),
      'positionMillis': controller.currentPosition,
      'playbackSpeed': controller.speed,
      'canSkipToNext': canSkipToNext,
      'canSkipToPrevious': canSkipToPrevious,
    };

    // use an isolate as this platform call is triggered on every video status update
    final SendPort port = await _updateIsolateSendPort;
    port.send(MediaSessionUpdateRequest(args));
    return;
  }

  @override
  Future<void> release() async {
    try {
      await _sessionChannel.invokeMethod('release');
    } on PlatformException catch (e, stack) {
      await reportService.recordError(e, stack);
    }
  }

  String _toPlatformState(VideoStatus status) {
    switch (status) {
      case VideoStatus.paused:
        return 'paused';
      case VideoStatus.playing:
        return 'playing';
      case VideoStatus.idle:
      case VideoStatus.initialized:
      case VideoStatus.completed:
      case VideoStatus.error:
        return 'stopped';
    }
  }

  void _onMediaCommand(Map? fields) {
    if (fields == null) return;
    final command = fields['command'] as String?;
    MediaCommandEvent? event;
    switch (command) {
      case 'play':
        event = const MediaCommandEvent(MediaCommand.play);
      case 'pause':
        event = const MediaCommandEvent(MediaCommand.pause);
      case 'skip_to_next':
        event = const MediaCommandEvent(MediaCommand.skipToNext);
      case 'skip_to_previous':
        event = const MediaCommandEvent(MediaCommand.skipToPrevious);
      case 'stop':
        event = const MediaCommandEvent(MediaCommand.stop);
      case 'seek':
        final position = fields['position'] as int?;
        if (position != null) {
          event = MediaSeekCommandEvent(MediaCommand.stop, position: position);
        }
    }
    if (event != null) {
      _streamController.add(event);
    }
  }

  final Future<SendPort> _updateIsolateSendPort = () async {
    // The helper isolate is going to send us back a SendPort, which we want to wait for.
    final Completer<SendPort> completer = Completer<SendPort>();

    final ReceivePort receivePort = ReceivePort()
      ..listen((dynamic data) {
        if (data is SendPort) {
          // The helper isolate sent us the port on which we can sent it requests.
          completer.complete(data);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    Future<void> entryPoint(isolateData) async {
      BackgroundIsolateBinaryMessenger.ensureInitialized(isolateData.token);

      final ReceivePort helperReceivePort = ReceivePort()
        ..listen((dynamic data) async {
          if (data is MediaSessionUpdateRequest) {
            try {
              await _sessionChannel.invokeMethod('update', data.args);
            } on PlatformException catch (e, stack) {
              await reportService.recordError(e, stack);
            }
            return;
          }
          throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
        });

      // Send the port to the main isolate on which we can receive requests.
      isolateData.answerPort.send(helperReceivePort.sendPort);
    }

    await Isolate.spawn<_IsolateData>(
      entryPoint,
      _IsolateData(
        token: ServicesBinding.rootIsolateToken!,
        answerPort: receivePort.sendPort,
      ),
      debugName: _sessionChannel.name,
    );

    // Wait until the helper isolate has sent us back the SendPort on which we can start sending requests.
    return completer.future;
  }();
}

enum MediaCommand { play, pause, skipToNext, skipToPrevious, stop, seek }

@immutable
class MediaCommandEvent extends Equatable {
  final MediaCommand command;

  @override
  List<Object?> get props => [command];

  const MediaCommandEvent(this.command);
}

@immutable
class MediaSeekCommandEvent extends MediaCommandEvent {
  final int position;

  @override
  List<Object?> get props => [...super.props, position];

  const MediaSeekCommandEvent(super.command, {required this.position});
}

// isolate related classes

@immutable
class MediaSessionUpdateRequest {
  final Map<String, Object?> args;

  const MediaSessionUpdateRequest(this.args);
}

class _IsolateData {
  final RootIsolateToken token;
  final SendPort answerPort;

  _IsolateData({
    required this.token,
    required this.answerPort,
  });
}
