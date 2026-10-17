import 'logic/notifier.dart';
import 'logic/roll_store.dart';
import 'logic/tickets.dart';

/// 앱 전체에서 같이 쓰는 저장소들.
class RollApp {
  static final Notifier notifier = Notifier();
  static final RollStore store = RollStore(notifier: notifier);
  static final Tickets tickets = Tickets();
}
