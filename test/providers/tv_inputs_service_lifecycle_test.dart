import 'dart:async';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/providers/tv_inputs_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedInputsChannel extends FLauncherChannel {
  final Completer<List<Map<dynamic, dynamic>>> response = Completer();

  @override
  Future<List<Map<dynamic, dynamic>>> getTvInputs() => response.future;
}

void main() {
  test('late platform response does not update a disposed service', () async {
    final channel = _DelayedInputsChannel();
    final service = TvInputsService(channel);
    service.dispose();

    channel.response.complete([
      {'id': 'hdmi1', 'label': 'HDMI 1', 'type': 1007},
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(service.inputs, isEmpty);
    expect(service.initialized, isFalse);
  });

  test('platform failure finishes initialization without an async error', () async {
    final channel = _DelayedInputsChannel();
    final service = TvInputsService(channel);

    channel.response.completeError(StateError('TV input service unavailable'));
    await Future<void>.delayed(Duration.zero);

    expect(service.initialized, isTrue);
    expect(service.inputs, isEmpty);
    service.dispose();
  });
}
