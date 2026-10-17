import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'notifier.dart';
import 'roll.dart';

/// 롤과 사진을 폰 안에 보관한다. (`rolls.json` + `rolls/<번호>/<n>.jpg`)
class RollStore extends ChangeNotifier {
  RollStore({this.notifier, math.Random? rng}) : _rng = rng ?? math.Random();

  final Notifier? notifier;
  final math.Random _rng;

  late Directory _root;
  final List<RollRecord> _rolls = [];

  List<RollRecord> get rolls => List.unmodifiable(_rolls);

  /// 지금 찍고 있는 롤 (없으면 null)
  RollRecord? get active {
    for (final r in _rolls) {
      if (r.sealedAt == null) return r;
    }
    return null;
  }

  RollRecord? byNo(int no) {
    for (final r in _rolls) {
      if (r.no == no) return r;
    }
    return null;
  }

  /// 현상이 끝났는데 아직 안 열어 본 롤
  RollRecord? get firstReady {
    final now = DateTime.now();
    for (final r in _rolls) {
      if (r.statusAt(now) == RollStatus.ready) return r;
    }
    return null;
  }

  File get _jsonFile => File('${_root.path}/rolls.json');

  Future<void> init({Directory? dir}) async {
    _root = dir ?? await getApplicationDocumentsDirectory();
    if (await _jsonFile.exists()) {
      try {
        final list = jsonDecode(await _jsonFile.readAsString()) as List;
        _rolls
          ..clear()
          ..addAll(list.map((e) => RollRecord.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // 파일이 깨졌으면 빈 상태로 시작한다. (사진 파일은 그대로 남는다)
      }
    }
  }

  Future<void> _save() async {
    final tmp = File('${_jsonFile.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final r in _rolls) r.toJson()]), flush: true);
    await tmp.rename(_jsonFile.path);
    notifyListeners();
  }

  File fileOf(Shot s) => File('${_root.path}/${s.file}');

  /// 새 롤을 끼운다.
  Future<RollRecord> startRoll(String filterId) async {
    final no = (_rolls.isEmpty ? 0 : _rolls.map((r) => r.no).reduce(math.max)) + 1;
    final roll = RollRecord(no: no, filterId: filterId, startedAt: DateTime.now());
    _rolls.add(roll);
    await _save();
    return roll;
  }

  /// 찍은 사진(필터가 입혀진 JPEG)을 롤에 넣는다.
  Future<Shot> addShot(RollRecord roll, Uint8List jpeg, DateTime takenAt) async {
    final n = roll.shots.length + 1;
    final rel = 'rolls/${roll.no}/${n.toString().padLeft(2, '0')}.jpg';
    final f = File('${_root.path}/$rel');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(jpeg, flush: true);
    final shot = Shot(file: rel, takenAt: takenAt);
    roll.shots.add(shot);
    await _save();
    return shot;
  }

  /// 롤을 현상에 맡긴다. 1~6시간 뒤에 끝나고 알림이 온다.
  Future<void> seal(RollRecord roll, {DateTime? now}) async {
    final t = now ?? DateTime.now();
    roll.sealedAt = t;
    roll.developAt = t.add(randomDevelopDelay(_rng));
    await _save();
    await notifier?.scheduleDeveloped(roll.no, roll.developAt!, roll.filter.title);
  }

  /// 티켓을 써서 바로 현상한다.
  Future<void> developNow(RollRecord roll, {DateTime? now}) async {
    roll.developAt = now ?? DateTime.now();
    await _save();
    await notifier?.cancel(roll.no);
  }

  Future<void> markRevealed(RollRecord roll) async {
    if (roll.revealed) return;
    roll.revealed = true;
    await _save();
  }
}
