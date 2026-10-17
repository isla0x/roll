import 'package:flutter/material.dart';

import '../logic/filters.dart';
import '../theme.dart';

/// 비네팅(가장자리 어둡게)을 얹는 덮개. 뷰파인더와 필터 미리보기에 쓴다.
class VignetteOverlay extends StatelessWidget {
  const VignetteOverlay({super.key, required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: .95,
            colors: [Colors.transparent, Colors.black.withValues(alpha: (strength * .9).clamp(0.0, 1.0))],
            stops: const [.35, 1],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 필터 고르는 줄의 작은 미리보기. 사진 대신 간단한 풍경 그림에 필터를 입힌다.
class FilterThumb extends StatelessWidget {
  const FilterThumb({super.key, required this.filter});

  final RollFilter filter;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: filter.previewFilter,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _ScenePainter()),
          VignetteOverlay(strength: filter.vignette),
        ],
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFBFD3E6), Color(0xFFF1E4CF)],
      ).createShader(Offset.zero & s);
    canvas.drawRect(Offset.zero & s, sky);
    canvas.drawRect(Rect.fromLTWH(0, s.height * .72, s.width, s.height * .28), Paint()..color = const Color(0xFF8E9B6A));
    // 집
    canvas.drawRect(Rect.fromLTWH(s.width * .22, s.height * .42, s.width * .56, s.height * .34), Paint()..color = const Color(0xFFE9D8BD));
    final roof = Path()
      ..moveTo(s.width * .16, s.height * .43)
      ..lineTo(s.width * .5, s.height * .24)
      ..lineTo(s.width * .84, s.height * .43)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFB5604A));
    canvas.drawRect(Rect.fromLTWH(s.width * .44, s.height * .56, s.width * .13, s.height * .2), Paint()..color = const Color(0xFF6B4A36));
    canvas.drawCircle(Offset(s.width * .84, s.height * .16), s.width * .09, Paint()..color = const Color(0xFFFFF3C4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 필터 이름 아래 줄에 붙는 사진 미리보기 틀 (살짝 기울어진 인화지).
class TiltedThumb extends StatelessWidget {
  const TiltedThumb({super.key, required this.filter, required this.tilt});

  final RollFilter filter;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt * 3.1415926535 / 180,
      child: Container(
        width: 46,
        height: 58,
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: RollColors.mat,
          boxShadow: [BoxShadow(color: Color(0x241C1B19), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: FilterThumb(filter: filter),
      ),
    );
  }
}
