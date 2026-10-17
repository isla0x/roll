import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, ColorFilter;

import 'package:image/image.dart' as img;

import 'retouch.dart';

/// 날짜 스탬프 (사진 오른쪽에 세로로 찍히는 노란/주황 점 글씨).
class StampSpec {
  const StampSpec({required this.pattern, required this.color, required this.y0});

  /// `yy` `MM` `dd` `yyyy` 를 날짜로 바꾼다.
  final String pattern;

  /// 0xRRGGBB
  final int color;

  /// 스탬프가 시작되는 세로 위치 (사진 높이의 비율)
  final double y0;

  String text(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return pattern
        .replaceAll('yyyy', d.year.toString().padLeft(4, '0'))
        .replaceAll('yy', two(d.year % 100))
        .replaceAll('MM', two(d.month))
        .replaceAll('dd', two(d.day));
  }
}

/// 롤에 끼우는 필터 하나.
///
/// [params] 순서: lift, gain, contrast, gainR, gainG, gainB,
/// 그림자 색(3), 밝은 곳 색(3), 채도, 비네팅.
class RollFilter {
  const RollFilter({
    required this.id,
    required this.year,
    required this.name,
    required this.note,
    required this.params,
    required this.grain,
    this.stamp,
  });

  final String id;
  final String year;
  final String name;
  final String note;
  final List<double> params;
  final double grain;
  final StampSpec? stamp;

  /// "1998년 할머니집"
  String get title => '$year년 $name';

  /// 사진 한 점(0~1)에 필터를 적용한다. [r] 은 가운데에서 코너까지의 거리 (0~1).
  List<double> applyPixel(double r0, double g0, double b0, double r) {
    final p = params;
    final lift = p[0], gain = p[1], con = p[2];
    var c0 = ((r0 * p[3] - .5) * con + .5);
    var c1 = ((g0 * p[4] - .5) * con + .5);
    var c2 = ((b0 * p[5] - .5) * con + .5);
    final k = (1 - lift) * gain;
    c0 = lift + c0 * k;
    c1 = lift + c1 * k;
    c2 = lift + c2 * k;
    final l = .299 * c0 + .587 * c1 + .114 * c2;
    final ws = (1 - l) * (1 - l), wh = l * l;
    c0 += ws * p[6] + wh * p[9];
    c1 += ws * p[7] + wh * p[10];
    c2 += ws * p[8] + wh * p[11];
    final g = .299 * c0 + .587 * c1 + .114 * c2;
    final sat = p[12];
    c0 = g + (c0 - g) * sat;
    c1 = g + (c1 - g) * sat;
    c2 = g + (c2 - g) * sat;
    final rr = r < 0 ? 0.0 : (r > 1 ? 1.0 : r);
    final v = 1 - p[13] * math.pow(rr, 2.2);
    return [_clamp(c0 * v), _clamp(c1 * v), _clamp(c2 * v)];
  }

  /// 라이브 뷰파인더용 근사 색 행렬 (그림자/밝은 곳 색은 평균값으로 더한다).
  /// 비네팅과 입자는 화면 위에 따로 얹는다.
  ColorFilter get previewFilter {
    final p = params;
    final lift = p[0], gain = p[1], con = p[2], sat = p[12];
    final k = (1 - lift) * gain;
    final gains = [p[3], p[4], p[5]];
    final scale = [for (final g in gains) g * con * k];
    final off = <double>[
      for (var i = 0; i < 3; i++) lift + (.5 - .5 * con) * k + .25 * (p[6 + i] + p[9 + i]),
    ];
    const lw = [.299, .587, .114];
    final m = List<double>.filled(20, 0);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final lumaPart = (1 - sat) * lw[col] * scale[col];
        final selfPart = row == col ? sat * scale[col] : 0.0;
        m[row * 5 + col] = lumaPart + selfPart;
      }
      // 채도를 거친 뒤의 오프셋
      m[row * 5 + 4] = ((1 - sat) * (lw[0] * off[0] + lw[1] * off[1] + lw[2] * off[2]) + sat * off[row]) * 255;
    }
    m[18] = 1;
    return ColorFilter.matrix(m);
  }

  Color get vignetteColor => const Color(0xFF000000);
  double get vignette => params[13];
}

double _clamp(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// 화면에 보이는 순서 (Load 화면 · 앨범).
const List<RollFilter> rollFilters = [
  RollFilter(
    id: 'kde',
    year: '1998',
    name: '할머니집',
    note: '따뜻하고 포근한 낮',
    grain: .004,
    params: [0.0793, 1.0038, 1.0413, 1.0429, 0.9639, 1.0075, 0.1132, 0.1094, 0.0703, 0.0217, 0.0414, -0.0441, 1.1120, 0.16],
  ),
  RollFilter(
    id: 'autox',
    year: '2001',
    name: '수학여행',
    note: '초록빛 일회용 카메라',
    grain: .012,
    stamp: StampSpec(pattern: "'yy MM dd", color: 0xFFD62A, y0: .665),
    params: [0.0720, 1.0374, 1.2461, 0.8876, 0.9687, 0.9989, 0.0652, 0.1494, 0.1243, 0.1494, 0.0677, 0.0314, 0.8948, 0.58],
  ),
  RollFilter(
    id: 'mira',
    year: '2009',
    name: '새벽 편의점',
    note: '푸르게 가라앉은 밤',
    grain: .02,
    stamp: StampSpec(pattern: 'yyyy.MM.dd', color: 0xFF8A28, y0: .80),
    params: [0.0944, 0.9623, 1.1786, 1.0000, 0.9660, 1.0078, -0.0287, 0.1498, 0.1297, 0.0148, 0.0277, 0.0210, 1.1285, 0.85],
  ),
  RollFilter(
    id: 'se',
    year: '2022',
    name: '아빠의 시선',
    note: '담백하고 차분하게',
    grain: .004,
    params: [0.0, 0.8069, 1.1715, 0.9824, 0.9810, 0.9959, 0.1246, 0.1445, 0.1468, 0.1494, 0.1494, 0.0502, 1.1396, 0.22],
  ),
  RollFilter(
    id: '4s',
    year: '2011',
    name: '첫 스마트폰',
    note: '또렷하고 환한 옛 폰카',
    grain: .007,
    params: [0.0166, 1.0898, 1.3041, 0.8926, 0.9229, 0.9598, 0.1494, 0.1500, 0.1476, 0.1417, 0.1159, 0.0402, 1.0059, 0.24],
  ),
  RollFilter(
    id: 'kh24',
    year: '1996',
    name: '여름방학',
    note: '바랜 필름의 푸른 여름',
    grain: .034,
    params: [0.0446, 1.0147, 1.0545, 0.9248, 1.0003, 1.1076, 0.1438, 0.1487, 0.1494, 0.1012, 0.0734, -0.0432, 1.0884, 0.70],
  ),
];

RollFilter filterById(String id) => rollFilters.firstWhere((f) => f.id == id, orElse: () => rollFilters.first);

// ───────────────────────── 사진 처리 ─────────────────────────

/// 최종 사진 크기 (3:4 세로).
const int shotWidth = 1080;
const int shotHeight = 1440;

class ProcessRequest {
  const ProcessRequest({
    required this.jpeg,
    required this.filterId,
    required this.takenAt,
    this.mirror = false,
    this.seed = 1,
    this.faces = const [],
    this.retouch = 0,
  });

  final Uint8List jpeg;
  final String filterId;
  final DateTime takenAt;

  /// 셀카(전면 카메라)는 좌우를 뒤집는다.
  final bool mirror;
  final int seed;

  /// 사진에서 찾은 얼굴 (카메라가 찍은 원본 사진 기준)
  final List<FaceBox> faces;

  /// 얼굴 보정 세기 0~1 (0 이면 끔)
  final double retouch;
}

/// 카메라가 찍은 JPEG 를 3:4 로 자르고 필터 · 입자 · 날짜 스탬프를 입혀 JPEG 로 돌려준다.
/// 시간이 걸리므로 `Isolate.run` / `compute` 안에서 부른다.
Uint8List processShot(ProcessRequest req) {
  final filter = filterById(req.filterId);
  var src = img.decodeImage(req.jpeg);
  if (src == null) throw const FormatException('사진을 읽을 수 없어요');
  src = img.bakeOrientation(src);
  final srcWidth = src.width.toDouble();
  if (req.mirror) src = img.flipHorizontal(src);

  // 가운데를 3:4 세로로 자른다.
  var cw = src.width, ch = src.height;
  if (cw * 4 > ch * 3) {
    cw = (ch * 3 / 4).round();
  } else {
    ch = (cw * 4 / 3).round();
  }
  final cropX = (src.width - cw) ~/ 2, cropY = (src.height - ch) ~/ 2;
  final cropped = img.copyCrop(src, x: cropX, y: cropY, width: cw, height: ch);
  final sized = img.copyResize(cropped, width: shotWidth, height: shotHeight, interpolation: img.Interpolation.average);

  final base = sized.numChannels == 3 ? sized : sized.convert(numChannels: 3);
  final rgb = base.getBytes(order: img.ChannelOrder.rgb);
  // 얼굴 보정 (필터를 입히기 전에, 얼굴 부분만 아주 약하게)
  if (req.retouch > 0 && req.faces.isNotEmpty) {
    final scale = shotWidth / cw;
    final boxes = [
      for (final f in req.faces)
        (req.mirror ? f.mirrored(srcWidth) : f).mapped(dx: cropX.toDouble(), dy: cropY.toDouble(), scale: scale),
    ];
    retouchFaces(rgb, shotWidth, shotHeight, base, boxes, strength: req.retouch);
  }

  final out = Uint8List(shotWidth * shotHeight * 3);
  final rng = math.Random(req.seed);
  final amp = filter.grain;

  // 채널값(0~255) → 필터 → 값 (빠르게 하려고 한 줄씩 비네팅 거리를 미리 계산)
  final halfW = shotWidth / 2, halfH = shotHeight / 2;
  final dx2 = Float64List(shotWidth);
  for (var x = 0; x < shotWidth; x++) {
    final dx = (x - halfW) / halfW;
    dx2[x] = dx * dx;
  }
  var i = 0;
  for (var y = 0; y < shotHeight; y++) {
    final dy = (y - halfH) / halfH;
    final dy2 = dy * dy;
    for (var x = 0; x < shotWidth; x++) {
      final r = math.sqrt(dx2[x] + dy2) / 1.414;
      final c = filter.applyPixel(rgb[i] / 255, rgb[i + 1] / 255, rgb[i + 2] / 255, r);
      // 입자: 밝기에만 얹는 가우시안 노이즈 (Box-Muller 대신 4개 평균으로 가볍게)
      final n = amp == 0 ? 0.0 : amp * ((rng.nextDouble() + rng.nextDouble() + rng.nextDouble() + rng.nextDouble() - 2) * 1.73);
      out[i] = _to8(c[0] + n);
      out[i + 1] = _to8(c[1] + n);
      out[i + 2] = _to8(c[2] + n);
      i += 3;
    }
  }

  final stamp = filter.stamp;
  if (stamp != null) {
    _drawStamp(out, shotWidth, shotHeight, stamp.text(req.takenAt), stamp.color, .86, stamp.y0, .095);
  }

  final result = img.Image.fromBytes(width: shotWidth, height: shotHeight, bytes: out.buffer, numChannels: 3);
  return Uint8List.fromList(img.encodeJpg(result, quality: 90));
}

int _to8(double v) {
  final n = (v * 255).round();
  return n < 0 ? 0 : (n > 255 ? 255 : n);
}

/// 5x7 점 글씨 (stamp 에 쓰는 글자만).
const Map<String, List<String>> _glyphs = {
  '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
  '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
  '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  '3': ['11110', '00001', '00001', '01110', '00001', '00001', '11110'],
  '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
  '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
  '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
  "'": ['00100', '00100', '01000', '00000', '00000', '00000', '00000'],
  '.': ['00000', '00000', '00000', '00000', '00000', '01100', '01100'],
  ' ': ['00000', '00000', '00000', '00000', '00000', '00000', '00000'],
};

/// 글자를 반시계로 90° 돌려 (아래→위로 읽히게) 점으로 찍는다.
void _drawStamp(Uint8List px, int w, int h, String text, int color, double xFrac, double y0Frac, double lengthFrac) {
  final cols = text.length * 6 - 1;
  final length = h * lengthFrac;
  final pitch = length / cols;
  final rad = pitch * .46;
  final ox = w * xFrac, oy = h * y0Frac;
  final cr = (color >> 16) & 0xFF, cg = (color >> 8) & 0xFF, cb = color & 0xFF;
  const alpha = .92;
  for (var ci = 0; ci < text.length; ci++) {
    final g = _glyphs[text[ci]] ?? _glyphs[' ']!;
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 5; col++) {
        if (g[row][col] != '1') continue;
        final tx = ci * 6 + col; // 글자 가로 위치
        final cx = ox + (row + .5) * pitch;
        final cy = oy + length - (tx + .5) * pitch;
        final x0 = (cx - rad).floor(), x1 = (cx + rad).ceil();
        final y0 = (cy - rad).floor(), y1 = (cy + rad).ceil();
        for (var yy = y0; yy <= y1; yy++) {
          if (yy < 0 || yy >= h) continue;
          for (var xx = x0; xx <= x1; xx++) {
            if (xx < 0 || xx >= w) continue;
            final d = math.sqrt((xx + .5 - cx) * (xx + .5 - cx) + (yy + .5 - cy) * (yy + .5 - cy));
            if (d > rad) continue;
            final o = (yy * w + xx) * 3;
            px[o] = (px[o] * (1 - alpha) + cr * alpha).round();
            px[o + 1] = (px[o + 1] * (1 - alpha) + cg * alpha).round();
            px[o + 2] = (px[o + 2] * (1 - alpha) + cb * alpha).round();
          }
        }
      }
    }
  }
}
