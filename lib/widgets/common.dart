import 'package:flutter/material.dart';

import '../theme.dart';

/// 맨 위 "Roll" 로고 + 오른쪽 작은 글씨.
class RollHeader extends StatelessWidget {
  const RollHeader({super.key, this.right, this.onRightTap});

  final String? right;
  final VoidCallback? onRightTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Roll', style: serif(44, spacing: -0.5, height: .9)),
        if (right != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRightTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(right!, style: serif(15, color: RollColors.muted)),
              ),
            ),
          ),
      ],
    );
  }
}

/// 잉크색 1px 테두리 사각 버튼. 오른쪽에 화살표.
class OutlineAction extends StatelessWidget {
  const OutlineAction({super.key, required this.label, required this.onTap, this.enabled = true, this.arrow = true});

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool arrow;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? RollColors.ink : RollColors.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(2)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(label, style: body(16, color: color, spacing: 1))),
            if (arrow) Text('→', style: serif(22, color: color)),
          ],
        ),
      ),
    );
  }
}

/// 흰 테두리가 있는 인화지 사진 틀.
class PrintMat extends StatelessWidget {
  const PrintMat({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(6, 6, 6, 20),
    this.angle = 0,
    this.strong = false,
  });

  final Widget child;
  final EdgeInsets padding;

  /// 도(degree)
  final double angle;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle * 3.1415926535 / 180,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: RollColors.mat,
          boxShadow: [
            const BoxShadow(color: Color(0x1F1C1B19), blurRadius: 2, offset: Offset(0, 1)),
            BoxShadow(color: Color(strong ? 0x291C1B19 : 0x141C1B19), blurRadius: strong ? 40 : 16, offset: Offset(0, strong ? 22 : 8)),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// 작은 금색 마름모.
class Diamond extends StatelessWidget {
  const Diamond({super.key, this.size = 6, this.color = RollColors.gold});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(angle: 3.1415926535 / 4, child: Container(width: size, height: size, color: color));
  }
}

/// 서서히 나타나는 화면 전환.
Route<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  );
}
