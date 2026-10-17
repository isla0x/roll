import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:roll/logic/filters.dart';

void main() {
  test('필터는 6종이고 이름이 겹치지 않는다', () {
    expect(rollFilters.length, 6);
    expect(rollFilters.map((f) => f.id).toSet().length, 6);
    expect(rollFilters.map((f) => f.title).toSet().length, 6);
    expect(rollFilters.map((f) => f.year).toList(), ['1998', '2001', '2009', '2022', '2011', '1996']);
  });

  test('날짜 스탬프 글자', () {
    final d = DateTime(2026, 10, 17);
    expect(filterById('autox').stamp!.text(d), "'26 10 17");
    expect(filterById('mira').stamp!.text(d), '2026.10.17');
    expect(filterById('kde').stamp, isNull);
  });

  test('픽셀 변환 결과는 항상 0~1', () {
    for (final f in rollFilters) {
      for (final v in [0.0, .25, .5, .75, 1.0]) {
        for (final r in [0.0, .5, 1.0, 1.4]) {
          final c = f.applyPixel(v, v * .8, v * .6, r);
          for (final x in c) {
            expect(x, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    }
  });

  test('mira 는 가장자리가 가운데보다 어둡다', () {
    final f = filterById('mira');
    final center = f.applyPixel(.5, .5, .5, 0);
    final corner = f.applyPixel(.5, .5, .5, 1);
    expect(corner[1], lessThan(center[1]));
  });

  test('사진 한 장을 처리하면 1080x1440 이고 스탬프가 찍힌다', () {
    final src = img.Image(width: 400, height: 300);
    for (final p in src) {
      p
        ..r = 120
        ..g = 140
        ..b = 110;
    }
    final jpeg = Uint8List.fromList(img.encodeJpg(src, quality: 90));
    final out = processShot(ProcessRequest(jpeg: jpeg, filterId: 'autox', takenAt: DateTime(2026, 10, 17)));
    final back = img.decodeJpg(out)!;
    expect(back.width, shotWidth);
    expect(back.height, shotHeight);
    // 노란 점 글씨가 오른쪽 어딘가에 있어야 한다.
    var yellow = 0;
    for (var y = (shotHeight * .6).round(); y < shotHeight * .8; y++) {
      for (var x = (shotWidth * .8).round(); x < shotWidth; x++) {
        final p = back.getPixel(x, y);
        if (p.r > 200 && p.g > 160 && p.b < 120) yellow++;
      }
    }
    expect(yellow, greaterThan(50));
  });
}
