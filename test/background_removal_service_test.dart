import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/background_removal/base_background_remover.dart';
import 'package:in4up/features/background_removal/background_removal_engine.dart';
import 'package:in4up/features/background_removal/background_removal_service.dart';

class _FakeRemover implements BaseBackgroundRemover {
  _FakeRemover(this.result, {this.error});

  final Uint8List? result;
  final Object? error;

  @override
  Future<Uint8List?> removeBackground(Uint8List imageBytes) async {
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  test('uses the selected strategy when it succeeds', () async {
    final service = BackgroundRemovalService(
      mlKit: _FakeRemover(Uint8List.fromList([1])),
      rmbg: _FakeRemover(Uint8List.fromList([2])),
    );

    final result = await service.removeBackground(
      Uint8List.fromList([9]),
      engine: BackgroundRemovalEngine.rmbg14,
    );

    expect(result, orderedEquals([2]));
  });

  test('falls back to ML Kit when the optional strategy fails', () async {
    final service = BackgroundRemovalService(
      mlKit: _FakeRemover(Uint8List.fromList([1])),
      rmbg: _FakeRemover(null, error: StateError('out of memory')),
    );

    final result = await service.removeBackground(
      Uint8List.fromList([9]),
      engine: BackgroundRemovalEngine.rmbg14,
    );

    expect(result, orderedEquals([1]));
  });
}
