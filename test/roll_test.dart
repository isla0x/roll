import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:roll/logic/roll.dart';
import 'package:roll/logic/roll_store.dart';

void main() {
  test('현상 시간은 항상 1시간 이상 6시간 이하', () {
    final rng = math.Random(7);
    for (var i = 0; i < 2000; i++) {
      final d = randomDevelopDelay(rng);
      expect(d.inMinutes, inInclusiveRange(60, 360));
    }
  });

  test('카운트다운 표시', () {
    expect(formatCountdown(const Duration(hours: 3, minutes: 12, seconds: 45)), '3:12:45');
    expect(formatCountdown(Duration.zero), '0:00:00');
    expect(formatCountdown(const Duration(seconds: -5)), '0:00:00');
  });

  test('롤 상태가 시간에 따라 바뀐다', () {
    final t0 = DateTime(2026, 10, 17, 12);
    final r = RollRecord(no: 1, filterId: 'kde', startedAt: t0);
    expect(r.statusAt(t0), RollStatus.shooting);
    r.sealedAt = t0;
    r.developAt = t0.add(const Duration(hours: 4));
    expect(r.statusAt(t0.add(const Duration(hours: 1))), RollStatus.developing);
    expect(r.progress(t0.add(const Duration(hours: 2))), closeTo(.5, .001));
    expect(r.remaining(t0.add(const Duration(hours: 1))), const Duration(hours: 3));
    expect(r.statusAt(t0.add(const Duration(hours: 5))), RollStatus.ready);
    r.revealed = true;
    expect(r.statusAt(t0.add(const Duration(hours: 5))), RollStatus.done);
  });

  test('롤을 저장했다가 다시 읽는다', () {
    final r = RollRecord(
      no: 3,
      filterId: 'mira',
      startedAt: DateTime(2026, 10, 1),
      shots: [Shot(file: 'rolls/3/01.jpg', takenAt: DateTime(2026, 10, 2))],
      sealedAt: DateTime(2026, 10, 3),
      developAt: DateTime(2026, 10, 3, 4),
      revealed: true,
    );
    final back = RollRecord.fromJson(r.toJson());
    expect(back.no, 3);
    expect(back.filterId, 'mira');
    expect(back.shots.single.file, 'rolls/3/01.jpg');
    expect(back.developAt, DateTime(2026, 10, 3, 4));
    expect(back.revealed, isTrue);
  });

  test('저장소: 롤 끼우기 → 사진 넣기 → 현상 맡기기 → 다시 열기', () async {
    final dir = await Directory.systemTemp.createTemp('roll_test');
    addTearDown(() => dir.delete(recursive: true));
    final store = RollStore(rng: math.Random(1));
    await store.init(dir: dir);
    expect(store.active, isNull);

    final roll = await store.startRoll('autox');
    expect(roll.no, 1);
    expect(store.active, same(roll));

    final now = DateTime(2026, 10, 17, 9);
    await store.addShot(roll, Uint8List.fromList([1, 2, 3]), now);
    expect(roll.shots.length, 1);
    expect(store.fileOf(roll.shots.first).existsSync(), isTrue);

    await store.seal(roll, now: now);
    expect(store.active, isNull);
    final wait = roll.developAt!.difference(now);
    expect(wait.inMinutes, inInclusiveRange(60, 360));
    expect(roll.statusAt(now), RollStatus.developing);

    final second = await store.startRoll('kde');
    expect(second.no, 2);

    final reopened = RollStore();
    await reopened.init(dir: dir);
    expect(reopened.rolls.length, 2);
    expect(reopened.byNo(1)!.shots.length, 1);

    await store.developNow(roll, now: now);
    expect(roll.statusAt(now), RollStatus.ready);
    await store.markRevealed(roll);
    expect(roll.statusAt(now), RollStatus.done);
  });
}
