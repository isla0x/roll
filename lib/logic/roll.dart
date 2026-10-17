import 'dart:math' as math;

import 'filters.dart';

/// 한 롤에 들어가는 사진 수.
const int rollSize = 24;

/// 롤의 상태.
enum RollStatus {
  /// 찍는 중
  shooting,

  /// 현상 맡김 (아직 못 봄)
  developing,

  /// 현상 끝 (아직 안 열어 봄)
  ready,

  /// 열어 본 롤
  done,
}

class Shot {
  const Shot({required this.file, required this.takenAt});

  /// 보관 폴더 기준 상대 경로 (`rolls/<롤 번호>/<번호>.jpg`)
  final String file;
  final DateTime takenAt;

  Map<String, dynamic> toJson() => {'file': file, 'takenAt': takenAt.toIso8601String()};

  factory Shot.fromJson(Map<String, dynamic> j) =>
      Shot(file: j['file'] as String, takenAt: DateTime.parse(j['takenAt'] as String));
}

class RollRecord {
  RollRecord({
    required this.no,
    required this.filterId,
    required this.startedAt,
    List<Shot>? shots,
    this.sealedAt,
    this.developAt,
    this.revealed = false,
  }) : shots = shots ?? [];

  /// 1부터 이어지는 롤 번호 (알림 id 로도 쓴다)
  final int no;
  final String filterId;
  final DateTime startedAt;
  final List<Shot> shots;

  /// 현상을 맡긴 시각 / 현상이 끝나는 시각
  DateTime? sealedAt;
  DateTime? developAt;
  bool revealed;

  RollFilter get filter => filterById(filterId);
  bool get isFull => shots.length >= rollSize;

  RollStatus statusAt(DateTime now) {
    if (sealedAt == null) return RollStatus.shooting;
    if (developAt != null && developAt!.isAfter(now)) return RollStatus.developing;
    return revealed ? RollStatus.done : RollStatus.ready;
  }

  /// 현상이 끝날 때까지 남은 시간 (끝났으면 0)
  Duration remaining(DateTime now) {
    final d = developAt;
    if (d == null || !d.isAfter(now)) return Duration.zero;
    return d.difference(now);
  }

  /// 현상 진행률 0~1
  double progress(DateTime now) {
    final s = sealedAt, d = developAt;
    if (s == null || d == null) return 0;
    final total = d.difference(s).inSeconds;
    if (total <= 0) return 1;
    return (now.difference(s).inSeconds / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'no': no,
        'filterId': filterId,
        'startedAt': startedAt.toIso8601String(),
        'shots': [for (final s in shots) s.toJson()],
        'sealedAt': sealedAt?.toIso8601String(),
        'developAt': developAt?.toIso8601String(),
        'revealed': revealed,
      };

  factory RollRecord.fromJson(Map<String, dynamic> j) => RollRecord(
        no: j['no'] as int,
        filterId: j['filterId'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        shots: [for (final s in (j['shots'] as List)) Shot.fromJson(s as Map<String, dynamic>)],
        sealedAt: j['sealedAt'] == null ? null : DateTime.parse(j['sealedAt'] as String),
        developAt: j['developAt'] == null ? null : DateTime.parse(j['developAt'] as String),
        revealed: j['revealed'] as bool? ?? false,
      );
}

/// 현상 대기 시간: 1시간 ~ 6시간 사이에서 1분 단위로 무작위.
Duration randomDevelopDelay(math.Random rng) => Duration(minutes: 60 + rng.nextInt(301));

/// "3:12:45"
String formatCountdown(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}
