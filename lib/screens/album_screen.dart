import 'package:flutter/material.dart';

import '../app.dart';
import '../logic/roll.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'load_screen.dart';
import 'reveal_screen.dart';
import 'rolls_screen.dart';

/// 5. 앨범 — 현상된 롤의 사진들이 인화지처럼 어긋나게 놓인다.
class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key, required this.rollNo});

  final int rollNo;

  static const _tilts = [-1.5, 1.5, 1.0, -1.0, -1.0, 1.0];

  String _dateLabel(RollRecord r) {
    final d = r.shots.isEmpty ? r.startedAt : r.shots.first.takenAt;
    return '${d.year}년 ${d.month}월 ${d.day}일에 찍은 ${r.shots.length}장';
  }

  @override
  Widget build(BuildContext context) {
    final roll = RollApp.store.byNo(rollNo)!;
    final f = roll.filter;
    final left = <int>[], right = <int>[];
    for (var i = 0; i < roll.shots.length; i++) {
      (i.isEven ? left : right).add(i);
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RollHeader(
                right: 'rolls',
                onRightTap: () => Navigator.of(context).push(fadeRoute<void>(const RollsScreen())),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(f.year, style: serif(64, weight: 300, spacing: -2, height: .9)),
                          const SizedBox(width: 14),
                          Text(f.name, style: body(19)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_dateLabel(roll), style: body(13, color: RollColors.muted)),
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Column(roll: roll, indices: left, leftColumn: true, tilts: _tilts)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 34),
                              child: _Column(roll: roll, indices: right, leftColumn: false, tilts: _tilts),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlineAction(
                label: RollApp.store.active != null ? '이어서 찍기' : '새 롤 끼우기',
                onTap: () => Navigator.of(context).push(fadeRoute<void>(const LoadScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.roll, required this.indices, required this.leftColumn, required this.tilts});

  final RollRecord roll;
  final List<int> indices;
  final bool leftColumn;
  final List<double> tilts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var j = 0; j < indices.length; j++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                fadeRoute<void>(RevealScreen(rollNo: roll.no, animate: false, initialIndex: indices[j])),
              ),
              child: PrintMat(
                angle: tilts[indices[j] % tilts.length],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: (j.isEven == leftColumn) ? 3 / 4 : 1,
                      child: Image.file(RollApp.store.fileOf(roll.shots[indices[j]]), fit: BoxFit.cover, cacheWidth: 400),
                    ),
                    const SizedBox(height: 6),
                    Text('no. ${(indices[j] + 1).toString().padLeft(2, '0')}', style: serif(12, color: RollColors.muted)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
