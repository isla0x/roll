import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../app.dart';
import '../logic/roll.dart';
import '../logic/tickets.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'load_screen.dart';
import 'reveal_screen.dart';
import 'rolls_screen.dart';

/// 3. 현상 중 — 남은 시간이 흐르고, 사진은 번져서 아직 알아볼 수 없다.
class DevelopScreen extends StatefulWidget {
  const DevelopScreen({super.key, required this.rollNo});

  final int rollNo;

  @override
  State<DevelopScreen> createState() => _DevelopScreenState();
}

class _DevelopScreenState extends State<DevelopScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  RollRecord get _roll => RollApp.store.byNo(widget.rollNo)!;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    _now = DateTime.now();
    if (_roll.statusAt(_now) != RollStatus.developing) {
      _timer?.cancel();
      Navigator.of(context).pushReplacement(fadeRoute<void>(RevealScreen(rollNo: widget.rollNo, animate: true)));
      return;
    }
    setState(() {});
  }

  Future<void> _developNow() async {
    final t = RollApp.tickets;
    if (t.count <= 0) {
      await t.buy();
      if (mounted && t.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.error!)));
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('바로 현상할까요?', style: body(18)),
        content: Text('티켓 1장을 써서 지금 바로 사진을 볼 수 있어요. (남은 티켓 ${t.count}장)', style: body(14, color: RollColors.muted, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('기다릴래요', style: body(15, color: RollColors.muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('바로 현상', style: body(15))),
        ],
      ),
    );
    if (ok != true) return;
    if (!await t.use()) return;
    await RollApp.store.developNow(_roll);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute<void>(RevealScreen(rollNo: widget.rollNo, animate: true)));
  }

  @override
  Widget build(BuildContext context) {
    final roll = _roll;
    final remaining = roll.remaining(_now);
    final pct = (roll.progress(_now) * 100).round();
    final totalMin = roll.sealedAt != null && roll.developAt != null ? roll.developAt!.difference(roll.sealedAt!).inMinutes : 0;
    final totalLabel = totalMin >= 60 ? '${(totalMin / 60).round()}시간' : '$totalMin분';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RollHeader(right: '${roll.filter.year} · ${roll.filter.name}'),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 56),
                      Text('developing', style: serif(19, color: RollColors.muted)),
                      const SizedBox(height: 8),
                      Text(formatCountdown(remaining), style: serif(92, weight: 300, spacing: -3, height: .9)),
                      const SizedBox(height: 14),
                      Text('사진이 천천히 떠오르고 있어요.\n조금만 기다려 주세요.', style: body(16, height: 1.6)),
                      const SizedBox(height: 30),
                      _ProgressLine(value: roll.progress(_now)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${roll.shots.length} frames', style: serif(14, color: RollColors.muted)),
                          Text('$totalLabel 중 $pct%', style: body(12, color: RollColors.muted)),
                        ],
                      ),
                      const SizedBox(height: 30),
                      _BlurredFan(roll: roll),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('다 되면 알림으로 알려드릴게요.', style: body(14, color: RollColors.muted)),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: RollApp.tickets,
                builder: (context, _) {
                  final t = RollApp.tickets;
                  final label = t.count > 0
                      ? '바로 현상하기 · 티켓 ${t.count}장'
                      : '바로 현상하기 · $ticketsPerPack회 ${t.priceLabel}';
                  return OutlineAction(label: label, onTap: _developNow, enabled: !t.purchasing);
                },
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _LinkText('새 롤 끼우기', () => Navigator.of(context).push(fadeRoute<void>(const LoadScreen()))),
                  _LinkText('앨범', () => Navigator.of(context).push(fadeRoute<void>(const RollsScreen()))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Align(widthFactor: 1, child: Text(label, style: body(14, color: RollColors.muted))),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final x = box.maxWidth * value;
        return SizedBox(
          height: 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(left: 0, right: 0, top: 3.5, child: Container(height: 1, color: RollColors.hair)),
              Positioned(left: 0, top: 3.5, child: Container(width: x, height: 1, color: RollColors.ink)),
              Positioned(left: x - 3.5, top: .5, child: const Diamond(size: 7)),
            ],
          ),
        );
      },
    );
  }
}

/// 현상 중인 사진 몇 장이 부채처럼 겹쳐 있는 그림. 너무 번져서 무슨 사진인지 알 수 없다.
class _BlurredFan extends StatelessWidget {
  const _BlurredFan({required this.roll});

  final RollRecord roll;

  static const _spec = [
    (x: 0.0, y: 24.0, r: -6.0),
    (x: 84.0, y: 0.0, r: 3.0),
    (x: 170.0, y: 30.0, r: -2.0),
    (x: 252.0, y: 6.0, r: 5.0),
  ];

  @override
  Widget build(BuildContext context) {
    final n = roll.shots.length < _spec.length ? roll.shots.length : _spec.length;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 356,
        height: 190,
        child: Stack(
          children: [
            for (var i = 0; i < n; i++)
              Positioned(
                left: _spec[i].x,
                top: _spec[i].y,
                child: SizedBox(
                  width: 104,
                  child: PrintMat(
                    angle: _spec[i].r,
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 22),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRect(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14, tileMode: TileMode.clamp),
                          child: Opacity(
                            opacity: .75,
                            child: Image.file(RollApp.store.fileOf(roll.shots[i]), fit: BoxFit.cover, cacheWidth: 120),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
