import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../logic/filters.dart';
import '../logic/roll.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/filter_thumb.dart';
import 'develop_screen.dart';
import 'rolls_screen.dart';

Future<Uint8List> _process(ProcessRequest r) => Isolate.run(() => processShot(r));

/// 2. 촬영 — 일반 카메라처럼 보이는 뷰파인더. 필터가 입혀진 채로 보인다.
class ShootScreen extends StatefulWidget {
  const ShootScreen({super.key, required this.rollNo});

  final int rollNo;

  @override
  State<ShootScreen> createState() => _ShootScreenState();
}

class _ShootScreenState extends State<ShootScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cams = [];
  int _camIdx = 0;
  CameraController? _c;
  String? _error;

  FlashMode _flash = FlashMode.off;
  double _zoom = 1;
  double _minZoom = 1;
  double _maxZoom = 1;
  bool _grid = true;
  bool _busy = false;
  bool _flashFrame = false;


  RollRecord get _roll => RollApp.store.byNo(widget.rollNo)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _c;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (c != null) {
        setState(() => _c = null);
        c.dispose();
      }
    } else if (state == AppLifecycleState.resumed && _c == null && _cams.isNotEmpty && !_busy) {
      _start(_cams[_camIdx]);
    }
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _grid = p.getBool('grid') ?? true);
      }
    } catch (_) {}
  }

  Future<void> _toggleGrid() async {
    setState(() => _grid = !_grid);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('grid', _grid);
    } catch (_) {}
  }

  Future<void> _initCamera() async {
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) {
        setState(() => _error = '카메라를 찾을 수 없어요.');
        return;
      }
      final back = _cams.indexWhere((d) => d.lensDirection == CameraLensDirection.back);
      _camIdx = back < 0 ? 0 : back;
      await _start(_cams[_camIdx]);
    } catch (e) {
      if (mounted) setState(() => _error = '카메라를 켤 수 없어요. 설정에서 카메라 권한을 확인해 주세요.');
    }
  }

  Future<void> _start(CameraDescription d) async {
    final old = _c;
    if (old != null) {
      setState(() => _c = null);
      await old.dispose();
    }
    final c = CameraController(d, ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    try {
      await c.initialize();
      _minZoom = await c.getMinZoomLevel();
      _maxZoom = await c.getMaxZoomLevel();
      _zoom = 1.0.clamp(_minZoom, _maxZoom).toDouble();
      try {
        await c.setFlashMode(_flash);
      } catch (_) {}
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _c = c;
        _error = null;
      });
    } catch (e) {
      await c.dispose();
      if (mounted) setState(() => _error = '카메라를 켤 수 없어요. 설정에서 카메라 권한을 확인해 주세요.');
    }
  }

  Future<void> _flip() async {
    if (_cams.length < 2 || _busy) return;
    final cur = _cams[_camIdx].lensDirection;
    final want = cur == CameraLensDirection.back ? CameraLensDirection.front : CameraLensDirection.back;
    final i = _cams.indexWhere((d) => d.lensDirection == want);
    if (i < 0) return;
    _camIdx = i;
    await _start(_cams[i]);
  }

  Future<void> _cycleFlash() async {
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    setState(() => _flash = next);
    try {
      await _c?.setFlashMode(next);
    } catch (_) {}
  }

  String get _flashLabel => switch (_flash) {
        FlashMode.off => 'flash off',
        FlashMode.auto => 'flash auto',
        _ => 'flash on',
      };

  Future<void> _setZoom(double z) async {
    final v = z.clamp(_minZoom, _maxZoom).toDouble();
    setState(() => _zoom = v);
    try {
      await _c?.setZoomLevel(v);
    } catch (_) {}
  }

  Future<void> _shoot() async {
    final c = _c;
    if (c == null || !c.value.isInitialized || _busy) return;
    final roll = _roll;
    if (roll.isFull) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final x = await c.takePicture();
      final bytes = await x.readAsBytes();
      final now = DateTime.now();
      final req = ProcessRequest(
        jpeg: bytes,
        filterId: roll.filterId,
        takenAt: now,
        mirror: c.description.lensDirection == CameraLensDirection.front,
        seed: roll.no * 100 + roll.shots.length,
      );
      setState(() => _flashFrame = true);
      Future<void>.delayed(const Duration(milliseconds: 140), () {
        if (mounted) setState(() => _flashFrame = false);
      });
      final out = await _process(req);
      try {
        await File(x.path).delete();
      } catch (_) {}
      await RollApp.store.addShot(roll, out, now);
      if (!mounted) return;
      setState(() {});
      if (roll.isFull) {
        await _sealAndGo();
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진을 저장하지 못했어요. 다시 찍어 주세요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sealAndGo() async {
    final roll = _roll;
    await RollApp.store.seal(roll);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute<void>(DevelopScreen(rollNo: roll.no)));
  }

  Future<void> _askSeal() async {
    final roll = _roll;
    if (roll.shots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('아직 찍은 사진이 없어요.')));
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('지금 현상 맡길까요?', style: body(18)),
        content: Text(
          '${roll.shots.length}장을 찍었어요. 맡기면 이 롤은 닫히고, 1~6시간 뒤에 사진을 볼 수 있어요.',
          style: body(14, color: RollColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('계속 찍기', style: body(15, color: RollColors.muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('현상 맡기기', style: body(15))),
        ],
      ),
    );
    if (go == true && mounted) await _sealAndGo();
  }

  @override
  Widget build(BuildContext context) {
    final roll = _roll;
    final filter = roll.filter;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: RollColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _viewfinder(filter),
          // 위아래 어둡게
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x80141311), Colors.transparent, Colors.transparent, Color(0x9E141311)],
                  stops: [0, .2, .66, 1],
                ),
              ),
            ),
          ),
          if (_grid) const IgnorePointer(child: CustomPaint(painter: _GridPainter())),
          // 초점 박스
          Align(
            alignment: const Alignment(0, -.08),
            child: IgnorePointer(child: Container(width: 64, height: 64, decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: .95))))),
          ),
          // 위 줄
          Positioned(
            left: 22,
            right: 22,
            top: pad.top + 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TextBtn(label: _flashLabel, onTap: _cycleFlash),
                Column(
                  children: [
                    Text(filter.title, style: body(16, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(filter.note, style: serif(13, color: Colors.white.withValues(alpha: .8))),
                  ],
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _askSeal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('${roll.shots.length}', style: serif(26, color: Colors.white)),
                        Text(' / $rollSize', style: serif(14, color: Colors.white.withValues(alpha: .8))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 줌
          Positioned(
            left: 0,
            right: 0,
            bottom: pad.bottom + 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_minZoom <= .6) _ZoomChip(label: '.5', selected: (_zoom - .5).abs() < .05, onTap: () => _setZoom(.5)),
                _ZoomChip(label: '1x', selected: (_zoom - 1).abs() < .05, onTap: () => _setZoom(1)),
                if (_maxZoom >= 2) _ZoomChip(label: '2', selected: (_zoom - 2).abs() < .05, onTap: () => _setZoom(2)),
              ],
            ),
          ),
          Positioned(
            right: 22,
            bottom: pad.bottom + 152,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleGrid,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 34),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_grid) const Diamond(color: Color(0xFFD9BD84)) else const SizedBox(width: 6),
                    const SizedBox(width: 6),
                    Text('grid ${_grid ? 'on' : 'off'}', style: serif(15, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: pad.bottom + 118,
            child: Center(child: Text('찍은 사진은 현상 뒤에 볼 수 있어요', style: body(12, color: Colors.white.withValues(alpha: .85)))),
          ),
          // 아래 줄
          Positioned(
            left: 28,
            right: 28,
            bottom: pad.bottom + 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundBtn(
                  label: 'rolls',
                  radius: 8,
                  onTap: () => Navigator.of(context).push(fadeRoute<void>(const RollsScreen())),
                ),
                GestureDetector(
                  onTap: _shoot,
                  child: Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: _busy ? 56 : 66,
                      height: _busy ? 56 : 66,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
                _RoundBtn(label: 'flip', radius: 26, onTap: _flip),
              ],
            ),
          ),
          // 셔터 순간 깜빡
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _flashFrame ? .85 : 0,
              duration: Duration(milliseconds: _flashFrame ? 40 : 220),
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewfinder(RollFilter filter) {
    final c = _c;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_error!, textAlign: TextAlign.center, style: body(15, color: Colors.white, height: 1.6)),
        ),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: RollColors.ink);
    }
    final ps = c.value.previewSize ?? const Size(1280, 720);
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: ps.height,
              height: ps.width,
              child: ColorFiltered(colorFilter: filter.previewFilter, child: CameraPreview(c)),
            ),
          ),
        ),
        VignetteOverlay(strength: filter.vignette),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .3)
      ..strokeWidth = 1;
    for (final f in [1 / 3, 2 / 3]) {
      canvas.drawLine(Offset(s.width * f, 0), Offset(s.width * f, s.height), p);
      canvas.drawLine(Offset(0, s.height * f), Offset(s.width, s.height * f), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TextBtn extends StatelessWidget {
  const _TextBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
        child: Align(alignment: Alignment.centerLeft, widthFactor: 1, child: Text(label, style: serif(18, color: Colors.white))),
      ),
    );
  }
}

class _ZoomChip extends StatelessWidget {
  const _ZoomChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 42.0 : 34.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? Colors.white.withValues(alpha: .9) : const Color(0x66141311),
          ),
          child: Text(label, style: serif(selected ? 16 : 14, color: selected ? RollColors.ink : Colors.white, weight: selected ? 500 : 400)),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.label, required this.radius, required this.onTap});

  final String label;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x66141311),
          borderRadius: BorderRadius.circular(radius),
          border: radius < 20 ? Border.all(color: Colors.white.withValues(alpha: .7)) : null,
        ),
        child: Text(label, style: serif(14, color: Colors.white)),
      ),
    );
  }
}
