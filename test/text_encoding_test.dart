import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib sources contain no mojibake', () {
    const tokens = ['Â', 'â', 'Ã'];
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final token in tokens) {
        if (content.contains(token)) hits.add('${entity.path}: $token');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
