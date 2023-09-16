import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:mutex/mutex.dart';
import 'package:repos_synchronizer/state/log_state.dart';
import 'package:repos_synchronizer/util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';

class GitProvider extends ChangeNotifier {
  static const String sharedPrefKey = 'currentPath';

  String _errorMessage = '';
  String get errorMessage => _errorMessage;
  set errorMessage(String value) {
    _errorMessage = value;
    LogState.addError(value);
    notifyListeners();
  }

  bool isUpdating = false;

  String headHash = '';
  String localHash = '';

  String _currentPath = '';
  String get currentPath => _currentPath;
  set currentPath(String value) {
    _currentPath = value;
    SharedPreferences.getInstance().then((x) => x.setString(sharedPrefKey, value));
    update();
  }

  bool localFilesModified = false;
  bool get isUpToDate => headHash == localHash;

  final GlobalKey<NavigatorState> navigatorKey;

  GitProvider(this.navigatorKey) {
    SharedPreferences.getInstance().then((x) => currentPath = x.getString(sharedPrefKey) ?? Directory.current.path);
  }

  Future changeDirectory() async {
    var dir = Directory(currentPath);
    Directory.current = dir;

    var gitDisabledDir = Directory('$currentPath${Platform.pathSeparator}.git_disabled');
    if (await gitDisabledDir.exists()) {
      LogState.addLog('Renaming ${gitDisabledDir.path} to ${gitDisabledDir.path.replaceAll('.git_disabled', '.git')}');
      await gitDisabledDir.rename('.git');
    }
  }

  Future renameBack() async {
    var gitDir = Directory('$currentPath${Platform.pathSeparator}.git');
    if (await gitDir.exists()) {
      LogState.addLog('Renaming ${gitDir.path} to ${gitDir.path.replaceAll('.git', '.git_disabled')}');
      await gitDir.rename('.git_disabled');
    }
  }

  Future modifyGitRecursively(String match, String targetName) async {
    var dir = Directory(currentPath);
    var list = await dir.list(recursive: true).where((x) => x.path.endsWith(match)).toList();
    for (var item in list) {
      try {
        LogState.addLog('Renaming ${item.path} to ${item.path.replaceAll(match, targetName)}');
        await item.rename(item.path.replaceAll(match, targetName));
      } on Exception catch (e) {
        var message = e.toString();
        if (!await showContinueQuestionDialog(message)) {
          errorMessage = message;
          return Future.error(message);
        }
      }
    }
  }

  Mutex directoryMutex = Mutex();
  Future hideGit() async => await modifyGitRecursively('.git', '.git_disabled');
  Future enableGit() async => await modifyGitRecursively('.git_disabled', '.git');

  Future<bool> showContinueQuestionDialog(String message) async {
    var result = await showDialog(
      context: navigatorKey.currentContext!,
      builder: (b) => ContentDialog(
        title: const Text('An error occured'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(navigatorKey.currentContext!, true),
            child: const Text('Yes'),
          ),
          Button(
            onPressed: () => Navigator.pop(navigatorKey.currentContext!, false),
            autofocus: true,
            style: ButtonStyle(
              backgroundColor: ButtonState.all(SystemTheme.accentColor.accent.toAccentColor()),
            ),
            child: const Text('No'),
          ),
        ],
        content: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            children: [
              Text(message),
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Text(
                  'Do you want to continue?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    ) as bool?;

    return result ?? false;
  }

  Future<bool> executeWithErrorCheck(Future Function() f) async {
    await f();

    if (errorMessage.isNotEmpty) {
      var result = await showContinueQuestionDialog(errorMessage);
      if (result == true) {
        errorMessage = '';
      } else {
        throw Exception(errorMessage);
      }
    }

    return true;
  }

  Future push() async {
    await directoryMutex.protect(() async {
      isUpdating = true;
      notifyListeners();

      LogState.addLog('Pushing...');

      if (!isUpToDate) {
        await pull(notify: false, useMutex: false);
      }

      try {
        await hideGit();
        await changeDirectory();

        var commitName = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
        await executeWithErrorCheck(() => Util.executeShellCommand('git add .'));
        await executeWithErrorCheck(() => Util.executeShellCommand('git commit -m $commitName'));
        await executeWithErrorCheck(() => Util.executeShellCommand('git push'));

        await update(useMutex: false);
      } catch (e) {
        errorMessage = e.toString();
        LogState.addError("Push error - ${e.toString()}");
      }

      try {
        await enableGit();
      } catch (e) {
        errorMessage += e.toString();
        LogState.addError("Push error - ${e.toString()}");
      }

      await renameBack();

      if (errorMessage.isEmpty) {
        LogState.addLog('Push successful');
      }

      isUpdating = false;
      notifyListeners();
    });
  }

  Future pull({bool notify = true, bool useMutex = true}) async {
    if (useMutex) {
      await directoryMutex.protect(() async => await pull(notify: notify, useMutex: false));
      return;
    }

    if (notify) {
      isUpdating = true;
      notifyListeners();
    }

    LogState.addLog('Pulling...');

    try {
      await hideGit();
      await changeDirectory();
      await executeWithErrorCheck(() => Util.executeShellCommand('git pull'));
      await update(notify: notify, useMutex: false);
    } catch (e) {
      errorMessage = e.toString();
      LogState.addError("Pull error - ${e.toString()}");
    }

    try {
      await enableGit();
    } catch (e) {
      errorMessage += e.toString();
      LogState.addError("Pull error - ${e.toString()}");
    }

    await renameBack();

    if (errorMessage.isEmpty) {
      LogState.addLog('Pull successful');
    }

    if (notify) {
      isUpdating = false;
      notifyListeners();
    }
  }

  Future update({bool notify = true, bool useMutex = true}) async {
    if (useMutex) {
      await directoryMutex.protect(() async => await update(notify: notify, useMutex: false));
      return;
    }

    LogState.addLog('Updating...');
    if (notify) {
      isUpdating = true;
      errorMessage = '';
      notifyListeners();
    }

    try {
      await changeDirectory();

      var newHeadHash = Util.executeShellCommand('git ls-remote');
      var newLocalHash = Util.executeShellCommand('git rev-parse HEAD');

      localHash = (await newLocalHash).trim();
      notifyListeners();
      headHash = ((await newHeadHash).split('\n')[0].split('\t')[0]).trim();
      notifyListeners();
    } catch (e) {
      LogState.addError("Update error - ${e.toString()}");
      errorMessage = e.toString();
    }

    try {
      await hideGit();
      String newStatus = '';
      await executeWithErrorCheck(() async => newStatus = await Util.executeShellCommand('git pull'));
      localFilesModified = newStatus.isNotEmpty;
    } catch (e) {
      errorMessage = e.toString();
      LogState.addError("Pull error - ${e.toString()}");
    }

    try {
      await enableGit();
    } catch (e) {
      errorMessage += e.toString();
      LogState.addError("Pull error - ${e.toString()}");
    }

    await renameBack();

    if (errorMessage.isEmpty) {
      LogState.addLog('Update successful');
    }

    if (notify) {
      isUpdating = false;
      notifyListeners();
    }
  }
}
