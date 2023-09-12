import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/scheduler.dart';

class LogState extends ChangeNotifier {
  static LogState? _instance;

  static final List<(String, Color)> _logs = [];
  static List<(String, Color)> get logs => _logs;
  static GlobalKey<AnimatedListState> logListKey = GlobalKey<AnimatedListState>();
  static ScrollController logListScrollController = ScrollController();

  LogState() {
    _instance = this;
  }

  static void addLog(String log, {Color color = Colors.white}) {
    log = log.trim();
    if (log.isEmpty) return;

    _logs.add((log, color));
    if (logListKey.currentState == null) return;

    logListKey.currentState!.insertItem(_logs.length - 1);
    _instance!.notifyListeners();

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      logListScrollController.animateTo(logListScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.bounceInOut);
    });
  }

  static void addError(String log) {
    addLog(log, color: Colors.red);
  }
}
