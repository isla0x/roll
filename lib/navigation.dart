import 'package:flutter/material.dart';

import 'logic/roll.dart';
import 'screens/album_screen.dart';
import 'screens/develop_screen.dart';
import 'screens/reveal_screen.dart';
import 'screens/shoot_screen.dart';
import 'widgets/common.dart';

/// 롤의 상태에 맞는 화면으로 이동한다.
Widget screenForRoll(RollRecord r) {
  switch (r.statusAt(DateTime.now())) {
    case RollStatus.shooting:
      return ShootScreen(rollNo: r.no);
    case RollStatus.developing:
      return DevelopScreen(rollNo: r.no);
    case RollStatus.ready:
      return RevealScreen(rollNo: r.no, animate: true);
    case RollStatus.done:
      return AlbumScreen(rollNo: r.no);
  }
}

void openRoll(BuildContext context, RollRecord r, {bool replace = false}) {
  final route = fadeRoute<void>(screenForRoll(r));
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}
