import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'logic/roll.dart';
import 'screens/load_screen.dart';
import 'screens/reveal_screen.dart';
import 'screens/shoot_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await RollApp.notifier.init();
  await RollApp.store.init();
  await RollApp.tickets.init();
  runApp(const RollAppWidget());
}

class RollAppWidget extends StatelessWidget {
  const RollAppWidget({super.key});

  /// 처음 보여 줄 화면: 찍던 롤이 있으면 촬영, 현상이 끝난 롤이 있으면 열어 보기, 없으면 롤 고르기.
  Widget _home() {
    final store = RollApp.store;
    final active = store.active;
    if (active != null && active.shots.isNotEmpty && active.statusAt(DateTime.now()) == RollStatus.shooting) {
      return ShootScreen(rollNo: active.no);
    }
    final ready = store.firstReady;
    if (ready != null) return RevealScreen(rollNo: ready.no, animate: true);
    if (active != null) return ShootScreen(rollNo: active.no);
    return const LoadScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roll',
      debugShowCheckedModeBanner: false,
      theme: rollTheme(),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        child: child ?? const SizedBox.shrink(),
      ),
      home: _home(),
    );
  }
}
