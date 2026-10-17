import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 사진 속에서 찾은 얼굴 하나 (사진 픽셀 기준 사각형).
class FaceBox {
  const FaceBox(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get cx => left + width / 2;
  double get cy => top + height / 2;

  /// 사진을 자르고 크기를 바꾼 뒤의 위치로 옮긴다.
  FaceBox mapped({required double dx, required double dy, required double scale}) =>
      FaceBox((left - dx) * scale, (top - dy) * scale, width * scale, height * scale);

  /// 사진을 좌우로 뒤집었을 때의 위치 ([imageWidth] 는 뒤집기 전 사진 너비).
  FaceBox mirrored(double imageWidth) => FaceBox(imageWidth - left - width, top, width, height);
}

/// 얼굴 부분만 아주 약하게 피부를 부드럽게 하고 조금 밝힌다.
///
/// [rgb] 는 [base] 와 같은 크기의 RGB 바이트 (결과를 여기에 쓴다).
/// [strength] 는 0~1. 필름 사진답게 티 나지 않는 정도는 0.5~0.7.
void retouchFaces(Uint8List rgb, int w, int h, img.Image base, List<FaceBox> faces, {double strength = .6}) {
  if (faces.isEmpty || strength <= 0) return;
  final src = base.numChannels == 3 ? base : base.convert(numChannels: 3);
  for (final f in faces) {
    final rx = f.width * .62, ry = f.height * .72;
    final x0 = math.max(0, (f.cx - rx).floor()), x1 = math.min(w - 1, (f.cx + rx).ceil());
    final y0 = math.max(0, (f.cy - ry).floor()), y1 = math.min(h - 1, (f.cy + ry).ceil());
    final rw = x1 - x0 + 1, rh = y1 - y0 + 1;
    if (rw < 8 || rh < 8) continue;
    final region = img.copyCrop(src, x: x0, y: y0, width: rw, height: rh);
    final blurred = img.gaussianBlur(region.clone(), radius: math.max(2, (f.width * .014).round()));
    final bb = blurred.getBytes(order: img.ChannelOrder.rgb);
    for (var y = 0; y < rh; y++) {
      final dy = (y0 + y - f.cy) / ry;
      for (var x = 0; x < rw; x++) {
        final dx = (x0 + x - f.cx) / rx;
        final d = dx * dx + dy * dy;
        if (d >= 1) continue;
        final m0 = 1 - d;
        final m = m0 * m0 * (3 - 2 * m0); // 가장자리가 부드럽게 사라진다
        final o = ((y0 + y) * w + (x0 + x)) * 3;
        final b = (y * rw + x) * 3;
        final s = strength * m;
        for (var c = 0; c < 3; c++) {
          final orig = rgb[o + c];
          var v = orig + (bb[b + c] - orig) * s * .8; // 부드럽게
          v += 255 * .035 * s; // 살짝 밝게
          rgb[o + c] = v < 0 ? 0 : (v > 255 ? 255 : v.round());
        }
      }
    }
  }
}
