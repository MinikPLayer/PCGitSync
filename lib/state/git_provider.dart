import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:mutex/mutex.dart';
import 'package:repos_synchronizer/util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GitProvider extends ChangeNotifier {
  static const String sharedPrefKey = 'currentPath';

  String errorMessage = '';

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

  GitProvider() {
    SharedPreferences.getInstance().then((x) => currentPath = x.getString(sharedPrefKey) ?? Directory.current.path);
  }

  Future changeDirectory() async {
    var dir = Directory(currentPath);
    Directory.current = dir;

    var gitDisabledDir = Directory('$currentPath${Platform.pathSeparator}.git_disabled');
    if (await gitDisabledDir.exists()) {
      await gitDisabledDir.rename('.git');
    }
  }

  Future renameBack() async {
    var gitDir = Directory('$currentPath${Platform.pathSeparator}.git');
    if (await gitDir.exists()) {
      await gitDir.rename('.git_disabled');
    }
  }

  Future modifyGitRecursively(String match, String targetName) async {
    var dir = Directory(currentPath);
    var list = dir.list(recursive: true).where((x) => x == match);
    await list.forEach((element) {
      element.rename(targetName);
    });
  }

  Mutex directoryMutex = Mutex();
  Future hideGit() => modifyGitRecursively('.git', '.git_disabled');
  Future enableGit() => modifyGitRecursively('.git_disabled', '.git');

  Future push() async {
    await directoryMutex.protect(() async {
      isUpdating = true;
      notifyListeners();

      if (!isUpToDate) {
        await pull(notify: false, useMutex: false);
      }

      try {
        await hideGit();
        await changeDirectory();
        var commitName = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
        await Util.executeShellCommand('git add .');
        await Util.executeShellCommand('git commit -m $commitName');
        await Util.executeShellCommand('git push');

        await update(useMutex: false);
        await enableGit();
      } catch (e) {
        errorMessage = e.toString();
      }

      await renameBack();

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

    try {
      await hideGit();
      await changeDirectory();
      await Util.executeShellCommand('git pull');
      await update(notify: notify, useMutex: false);
      await enableGit();
    } catch (e) {
      errorMessage = e.toString();
    }

    await renameBack();

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

    if (notify) {
      isUpdating = true;
      errorMessage = '';
      notifyListeners();
    }

    try {
      await changeDirectory();

      var newHeadHash = Util.executeShellCommand('git ls-remote');
      var newLocalHash = Util.executeShellCommand('git rev-parse HEAD');
      var newStatus = Util.executeShellCommand('git status --short');

      localHash = (await newLocalHash).trim();
      notifyListeners();
      headHash = ((await newHeadHash).split('\n')[0].split('\t')[0]).trim();
      notifyListeners();

      localFilesModified = (await newStatus).isNotEmpty;
    } catch (e) {
      errorMessage = e.toString();
    }

    await renameBack();

    if (notify) {
      isUpdating = false;
      notifyListeners();
    }
  }
}
