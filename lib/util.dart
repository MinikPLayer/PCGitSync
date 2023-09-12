import 'dart:io';

import 'package:repos_synchronizer/state/log_state.dart';

class Util {
  static Future<String> executeShellCommand(String command) async {
    var exec = '';
    var args = List<String>.empty(growable: true);
    if (Platform.isWindows) {
      exec = 'cmd';
      args.add('/c');
    } else if (Platform.isLinux || Platform.isMacOS) {
      exec = 'bash';
      args.add('-c');
    } else {
      throw Exception("Platform not supported");
    }

    args.add(command.replaceAll('"', '\\"'));
    var process = Process.run(exec, args);
    process.asStream().listen((event) {
      LogState.addLog(event.stdout.toString());
    });

    var processEnd = await process;

    if (processEnd.exitCode != 0) {
      if (processEnd.stderr.toString().isNotEmpty) {
        return Future.error(processEnd.stderr.toString());
      } else {
        return Future.error('Shell process execute with error code ${processEnd.exitCode}');
      }
    }

    return processEnd.stdout.toString();
  }
}
