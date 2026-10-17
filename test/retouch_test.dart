import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:roll/logic/live_faces.dart';
import 'package:roll/logic/retouch.dart';

void main() {
  test('얼굴 보정은 얼굴 안쪽 잡티를 줄이고 바깥은 그대로 둔다', () {
    const w = 200, h = 200;
    final rng = math.Random(3);
    final im = img.Image(width: w, height: h);
    for (final p in im) {
      final v = 120 + rng.nextInt(60);
      p
        ..r = v
        ..g = v
        ..b = v;
    }
    final rgb = Uint8List.fromList(im.getBytes(order: img.ChannelOrder.rgb));
    final before = Uint8List.fromList(rgb);
    const face = FaceBox(60, 60, 80, 80);
    retouchFaces(rgb, w, h, im, const [face], strength: .8);

    double variance(Uint8List b, int x0, int y0, int x1, int y1) {
      final vals = <int>[];
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          vals.add(b[(y * w + x) * 3]);
        }
      }
      final mean = vals.reduce((a, b) => a + b) / vals.length;
      return vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / vals.length;
    }

    // 얼굴 가운데는 잡음이 줄어든다.
    expect(variance(rgb, 80, 80, 120, 120), lessThan(variance(before, 80, 80, 120, 120) * .6));
    // 얼굴에서 멀리 떨어진 모서리는 그대로다.
    for (var y = 0; y < 20; y++) {
      for (var x = 0; x < 20; x++) {
        expect(rgb[(y * w + x) * 3], before[(y * w + x) * 3]);
      }
    }
  });

  test('상자 좌표 변환', () {
    const f = FaceBox(100, 50, 40, 60);
    final m = f.mapped(dx: 20, dy: 10, scale: 2);
    expect(m.left, 160);
    expect(m.top, 80);
    expect(m.width, 80);
    final flipped = f.mirrored(300);
    expect(flipped.left, 160);
  });

  test('라이브 얼굴 상자를 화면 위치로 바꾼다', () {
    // 화면 400x800, 카메라 화면 300x400 → 가로가 남아서 양옆이 잘린다 (배율 2)
    final r = mapToScreen(const Rect.fromLTWH(100, 100, 50, 50), const Size(300, 400), const Size(400, 800));
    expect(r.left, closeTo(100 * 2 - 100, .001));
    expect(r.top, closeTo(200, .001));
    expect(r.width, closeTo(100, .001));
    final m = mapToScreen(const Rect.fromLTWH(100, 100, 50, 50), const Size(300, 400), const Size(400, 800), mirror: true);
    expect(m.left, closeTo(400 - r.right, .001));
  });
}
