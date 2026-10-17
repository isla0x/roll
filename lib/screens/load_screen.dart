import 'package:flutter/material.dart';

import '../app.dart';
import '../logic/filters.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/filter_thumb.dart';
import 'rolls_screen.dart';
import 'shoot_screen.dart';

/// 1. 롤 끼우기 — 어떤 기억(필터)을 찍을지 고른다.
class LoadScreen extends StatefulWidget {
  const LoadScreen({super.key});

  @override
  State<LoadScreen> createState() => _LoadScreenState();
}

class _LoadScreenState extends State<LoadScreen> {
  int _sel = 0;
  bool _busy = false;

  static const _tilts = [-2.0, 2.0, -1.5, 1.5, -2.0, 2.0];

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    final store = RollApp.store;
    var roll = store.active;
    roll ??= await store.startRoll(rollFilters[_sel].id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute<void>(ShootScreen(rollNo: roll.no)));
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = RollApp.store.active != null;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListenableBuilder(
                listenable: RollApp.store,
                builder: (context, _) => RollHeader(
                  right: RollApp.store.rolls.isEmpty ? '12 exposures' : 'album',
                  onRightTap: RollApp.store.rolls.isEmpty
                      ? null
                      : () => Navigator.of(context).push(fadeRoute<void>(const RollsScreen())),
                ),
              ),
              const SizedBox(height: 26),
              Text(hasActive ? '찍던 롤이\n있어요.' : '어떤 기억을\n찍을까요?', style: body(27, spacing: -0.4, height: 1.4)),
              const SizedBox(height: 22),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: RollColors.hair))),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: rollFilters.length,
                    itemBuilder: (context, i) => _FilterRow(
                      filter: rollFilters[i],
                      selected: _sel == i,
                      tilt: _tilts[i],
                      onTap: hasActive ? null : () => setState(() => _sel = i),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                hasActive ? '아직 다 못 찍은 롤을 이어서 찍어요.' : '다 찍고 나면 한참 뒤에, 천천히 현상돼요.',
                style: body(14, color: RollColors.muted),
              ),
              const SizedBox(height: 12),
              OutlineAction(label: hasActive ? '이어서 찍기' : '롤 끼우기', onTap: _load, enabled: !_busy),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.filter, required this.selected, required this.tilt, required this.onTap});

  final RollFilter filter;
  final bool selected;
  final double tilt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 78,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: RollColors.hair))),
        child: Row(
          children: [
            SizedBox(width: 6, child: selected ? const Diamond() : null),
            const SizedBox(width: 16),
            SizedBox(width: 92, child: Text(filter.year, style: serif(46, weight: 300, spacing: -1))),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(filter.name, style: body(17, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(filter.note, style: body(12, color: RollColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            TiltedThumb(filter: filter, tilt: tilt),
          ],
        ),
      ),
    );
  }
}
