import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../app.dart';
import '../logic/roll.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'album_screen.dart';

/// 4. 현상 완료 — 사진이 위에서부터 서서히 또렷해진다. 옆으로 넘겨 본다.
class RevealScreen extends StatefulWidget {
  const RevealScreen({super.key, required this.rollNo, this.animate = true, this.initialIndex = 0});

  final int rollNo;
  final bool animate;
  final int initialIndex;

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> {
  late final PageController _pc;
  late int _page;
  final Set<int> _seen = {};
  bool _saving = false;

  RollRecord get _roll => RollApp.store.byNo(widget.rollNo)!;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.clamp(0, _roll.shots.isEmpty ? 0 : _roll.shots.length - 1);
    _pc = PageController(initialPage: _page);
    WidgetsBinding.instance.addPostFrameCallback((_) => RollApp.store.markRevealed(_roll));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final n = _roll.shots.length;
    final t = (_page + delta).clamp(0, n - 1);
    _pc.animateToPage(t, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  Future<void> _save() async {
    if (_saving) return;
    final roll = _roll;
    if (roll.shots.isEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) {
          messenger.showSnackBar(const SnackBar(content: Text('사진 보관함 권한이 필요해요. 설정에서 허용해 주세요.')));
          return;
        }
      }
      await Gal.putImage(RollApp.store.fileOf(roll.shots[_page]).path, album: 'Roll');
      messenger.showSnackBar(const SnackBar(content: Text('사진 보관함에 저장했어요.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 해 주세요.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roll = _roll;
    final n = roll.shots.length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RollHeader(right: '${_page + 1} of $n'),
                  const SizedBox(height: 22),
                  Text('현상이 끝났어요.', style: body(24, spacing: -0.3, height: 1.4)),
                ],
              ),
            ),
            Expanded(
              child: n == 0
                  ? Center(child: Text('사진이 없어요.', style: body(15, color: RollColors.muted)))
                  : PageView.builder(
                      controller: _pc,
                      itemCount: n,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) {
                        final play = widget.animate && _seen.add(i);
                        return _RevealPage(roll: roll, index: i, play: play);
                      },
                    ),
            ),
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: RollColors.hair))),
              child: Row(
                children: [
                  Expanded(child: _BarBtn(label: '이전', color: RollColors.muted, onTap: _page > 0 ? () => _go(-1) : null)),
                  Container(
                    decoration: const BoxDecoration(border: Border.symmetric(vertical: BorderSide(color: RollColors.hair))),
                    child: SizedBox(
                      width: 130,
                      child: _BarBtn(label: '저장', leading: const Diamond(), onTap: _save),
                    ),
                  ),
                  Expanded(
                    child: _BarBtn(
                      label: '앨범',
                      onTap: () => Navigator.of(context).pushReplacement(fadeRoute<void>(AlbumScreen(rollNo: widget.rollNo))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarBtn extends StatelessWidget {
  const _BarBtn({required this.label, this.onTap, this.color = RollColors.ink, this.leading});

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Text(label, style: body(15, color: onTap == null ? RollColors.hair : color)),
          ],
        ),
      ),
    );
  }
}

class _RevealPage extends StatefulWidget {
  const _RevealPage({required this.roll, required this.index, required this.play});

  final RollRecord roll;
  final int index;
  final bool play;

  @override
  State<_RevealPage> createState() => _RevealPageState();
}

class _RevealPageState extends State<_RevealPage> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600), value: widget.play ? 0 : 1);
    if (widget.play) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _ac.forward();
      });
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shot = widget.roll.shots[widget.index];
    final file = RollApp.store.fileOf(shot);
    final no = (widget.index + 1).toString().padLeft(2, '0');
    return LayoutBuilder(
      builder: (context, box) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: PrintMat(
              angle: 1.2,
              strong: true,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 3 / 4,
                    child: AnimatedBuilder(
                      animation: _ac,
                      builder: (context, _) {
                        final v = Curves.easeInOut.transform(_ac.value);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(file, fit: BoxFit.cover),
                            if (v < 1)
                              ShaderMask(
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (r) {
                                  final a = (v * 1.4 - .4).clamp(0.0, 1.0);
                                  final b = (v * 1.4).clamp(0.0, 1.0);
                                  return LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: const [Color(0x00000000), Color(0xFF000000)],
                                    stops: [a, b],
                                  ).createShader(r);
                                },
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18, tileMode: TileMode.clamp),
                                  child: Image.file(file, fit: BoxFit.cover),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(child: Text(widget.roll.filter.title, style: body(16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('no. $no', style: serif(15, color: RollColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
