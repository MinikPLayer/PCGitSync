import 'dart:io';

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
    var process = await Process.run(exec, args);
    if (process.exitCode != 0) {
      if (process.stderr.toString().isNotEmpty) {
        return Future.error(process.stderr.toString());
      } else {
        return Future.error('Shell process execute with error code ${process.exitCode}');
      }
    }

    return process.stdout.toString();
  }
}
