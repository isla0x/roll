import 'package:flutter/material.dart';

import '../app.dart';
import '../logic/roll.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 지금까지 끼운 롤 목록. 상태에 따라 찍기 · 현상 중 · 열어 보기 · 앨범으로 이어진다.
class RollsScreen extends StatelessWidget {
  const RollsScreen({super.key});

  String _status(RollRecord r, DateTime now) {
    switch (r.statusAt(now)) {
      case RollStatus.shooting:
        return '찍는 중 · ${r.shots.length}장';
      case RollStatus.developing:
        return '현상 중 · ${formatCountdown(r.remaining(now))} 남음';
      case RollStatus.ready:
        return '현상이 끝났어요 · 열어 보세요';
      case RollStatus.done:
        return '${r.shots.length}장';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RollHeader(right: 'close', onRightTap: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 26),
              Text('내 롤', style: body(27, spacing: -0.4, height: 1.4)),
              const SizedBox(height: 22),
              Expanded(
                child: ListenableBuilder(
                  listenable: RollApp.store,
                  builder: (context, _) {
                    final now = DateTime.now();
                    final rolls = RollApp.store.rolls.reversed.toList();
                    if (rolls.isEmpty) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Text('아직 롤이 없어요. 첫 롤을 끼워 보세요.', style: body(15, color: RollColors.muted)),
                      );
                    }
                    return Container(
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: RollColors.hair))),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: rolls.length,
                        itemBuilder: (context, i) {
                          final r = rolls[i];
                          final st = r.statusAt(now);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (st == RollStatus.shooting && Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              } else {
                                openRoll(context, r);
                              }
                            },
                            child: Container(
                              height: 78,
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: RollColors.hair))),
                              child: Row(
                                children: [
                                  SizedBox(width: 22, child: st == RollStatus.ready ? const Diamond() : null),
                                  SizedBox(width: 92, child: Text(r.filter.year, style: serif(46, weight: 300, spacing: -1))),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.filter.name, style: body(17, height: 1.2)),
                                        const SizedBox(height: 3),
                                        Text(_status(r, now), style: body(12, color: RollColors.muted)),
                                      ],
                                    ),
                                  ),
                                  Text('→', style: serif(20, color: RollColors.muted)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
