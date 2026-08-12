// Generates the Android launcher icons (all 5 mipmap densities) from the
// AscendLogoPainter.
//
// Run from the package root:
//   flutter test tool/generate_icons.dart
//
// Overwrites android/app/src/main/res/mipmap-*/ic_launcher.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend_app/widgets/ascend_logo_painter.dart';

void main() {
  const densities = <String, int>{
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  testWidgets('generate launcher icons', (tester) async {
    final root = Directory.current.path;
    final resDir = Directory('$root/android/app/src/main/res');
    expect(resDir.existsSync(), isTrue,
        reason: 'Run from the package root (where pubspec.yaml lives).');

    for (final entry in densities.entries) {
      final size = entry.value;
      final key = Key('icon_${entry.key}');

      // Center loosens the test view's tight 800x600 constraints so the
      // boundary hugs exactly the icon size.
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: size.toDouble(),
              height: size.toDouble(),
              child: CustomPaint(painter: const AscendLogoPainter()),
            ),
          ),
        ),
      );

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );

      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        expect(image.width, size, reason: '${entry.key} width');
        expect(image.height, size, reason: '${entry.key} height');

        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(byteData, isNotNull);

        final out = File(
          '$root/android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        );
        out.writeAsBytesSync(byteData!.buffer.asUint8List());
        // ignore: avoid_print
        print('✓ wrote ${out.path} (${out.lengthSync()} bytes)');
      });
    }

    // Never let the generator silently leave a stale density behind.
    for (final entry in densities.entries) {
      final f = File(
        '$root/android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      );
      expect(f.existsSync(), isTrue, reason: '${entry.key} exists');
    }
  });
}
