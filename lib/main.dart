import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as mat;
import 'package:flutter/scheduler.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as facrylic;
import 'package:flutter_acrylic/window_effect.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:repos_synchronizer/settings_page.dart';
import 'package:repos_synchronizer/state/git_provider.dart';
import 'package:repos_synchronizer/state/log_state.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:system_theme/system_theme.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

bool get isDesktop {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}

bool get isDarkMode {
  var brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
  return brightness == Brightness.dark;
}

Future<void> setSystemTrayIcon({bool delayed = true}) async {
  // Windows takes a while to change the theme, so we need to wait a bit (tbh yes, it's a bodged hack and not really needed xd)
  if (delayed) {
    await Future.delayed(const Duration(milliseconds: 100));
  }
  return trayManager.setIcon(isDarkMode ? 'assets/icon_dark_theme.ico' : 'assets/icon_light_theme.ico');
}

Future<void> initSystemTray() async {
  await trayManager.setToolTip("Repos synchronizer");
  await setSystemTrayIcon(delayed: false);

  final menu = Menu(items: [
    MenuItem(
      label: 'Show',
      key: "show",
      onClick: (i) => restoreWindow(useTrayPos: true, useTrayFullSize: true),
    ),
    MenuItem(
      label: 'Hide',
      key: "hide",
      onClick: (i) => windowManager.hide(),
    ),
    MenuItem(
      label: 'Exit',
      key: "exit",
      onClick: (i) async {
        await windowManager.setPreventClose(false);
        await windowManager.close();
      },
    ),
  ]);
  await trayManager.setContextMenu(menu);
}

Future restoreWindow({bool show = true, bool useTrayPos = false, bool useTrayFullSize = false}) async {
  if (show) {
    await windowManager.waitUntilReadyToShow(null, () async {
      var windowSize = const Size(450, 450);

      Offset? position;
      if (useTrayPos) {
        var bounds = await trayManager.getBounds();
        if (bounds != null) {
          if (!useTrayFullSize) {
            windowSize = const Size(450, 325);
          }
          position = Offset(bounds.left, bounds.top);
          position -= Offset(windowSize.width / 2, windowSize.height);
        }
      }

      if (position == null) {
        var cursorPos = await screenRetriever.getCursorScreenPoint();
        position = cursorPos - Offset(windowSize.width / 2, windowSize.height / 2);
      }

      await windowManager.setPosition(position);
      await windowManager.setSize(windowSize);
      windowManager.show();
    });
  }
}

Future setWindowEffects() {
  var osVersion = Platform.operatingSystemVersion;

  bool isWindows11 = false;
  if (Platform.isWindows) {
    const String buildString = "(Build ";
    var buildIndex = osVersion.indexOf(buildString);
    if (buildIndex != -1) {
      var build = osVersion.substring(buildIndex + buildString.length, osVersion.indexOf(')'));
      var buildInt = int.tryParse(build);
      if (buildInt != null && buildInt >= 22000) {
        isWindows11 = true;
      }
    }
  }

  if (isDesktop) {
    return facrylic.Window.setEffect(
      effect: isWindows11 ? WindowEffect.mica : WindowEffect.aero,
      color: Colors.black.withAlpha(196),
      dark: isDarkMode,
    );
  }

  return Future.value(true);
}

final navigationKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();

  // Open app hotkey
  var openAppHotkey = HotKey(
    KeyCode.keyR,
    modifiers: [KeyModifier.control, KeyModifier.alt],
    scope: HotKeyScope.system,
  );
  await hotKeyManager.register(openAppHotkey, keyDownHandler: (hotKey) {
    restoreWindow();
  });

  if (isDesktop) {
    await restoreWindow(show: false);
    await facrylic.Window.initialize();
    await setWindowEffects();

    await initSystemTray();
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _init();
  }

  void _init() async {
    await windowManager.setPreventClose(true);
    await windowManager.hide();
  }

  @override
  void dispose() {
    super.dispose();
    windowManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    restoreWindow(useTrayPos: true);
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    windowManager.hide();
    return AdaptiveTheme(
      initial: AdaptiveThemeMode.system,
      light: mat.ThemeData.light(),
      dark: mat.ThemeData.dark(),
      builder: (light, dark) {
        if (isDesktop) {
          setWindowEffects();
          setSystemTrayIcon();
        }

        return FluentApp(
          navigatorKey: navigationKey,
          debugShowCheckedModeBanner: false,
          home: ChangeNotifierProvider(
            create: (c) => GitProvider(navigationKey),
            child: const MyHomePage(title: 'Hello world!'),
          ),
          darkTheme: FluentThemeData(
            brightness: Brightness.dark,
            acrylicBackgroundColor: Colors.purple.withOpacity(0.5),
            inactiveBackgroundColor: Colors.transparent,
            activeColor: Colors.transparent,
            accentColor: SystemTheme.accentColor.accent.toAccentColor(),
            visualDensity: VisualDensity.standard,
            focusTheme: FocusThemeData(
              glowFactor: is10footScreen(context) ? 2.0 : 0.0,
            ),
            navigationPaneTheme: const NavigationPaneThemeData(
              backgroundColor: Colors.transparent,
            ),
          ),
          theme: FluentThemeData(
            accentColor: SystemTheme.accentColor.accent.toAccentColor(),
            acrylicBackgroundColor: Colors.transparent,
            inactiveBackgroundColor: Colors.transparent,
            visualDensity: VisualDensity.standard,
            focusTheme: FocusThemeData(
              glowFactor: is10footScreen(context) ? 2.0 : 0.0,
            ),
          ),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final LogState logState = LogState();

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    var p = Provider.of<GitProvider>(context, listen: true);
    List<Widget> children = [
      Text('Local Hash: ${p.localHash}'),
      Text('HEAD Hash: ${p.headHash}'),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Checkbox(
                checked: p.isUpToDate,
                content: const Text(
                  'Up to date',
                ),
                onChanged: null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Checkbox(
                checked: !p.localFilesModified,
                content: const Text(
                  'Local files unmodified',
                ),
                onChanged: null,
              ),
            ),
          ],
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Button(
              style: ButtonStyle(
                backgroundColor: p.isUpToDate || p.isUpdating
                    ? null
                    : ButtonState.all(
                        SystemTheme.accentColor.accent.toAccentColor(),
                      ),
              ),
              onPressed: p.isUpdating || p.isUpToDate ? null : () => p.pull(),
              child: const Row(
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(FluentIcons.download),
                  ),
                  Text('Pull'),
                ],
              ),
            ),
          ),
          Button(
            onPressed: p.isUpdating ? null : () => p.update(),
            child: const Row(
              children: [
                Text('Refresh'),
                Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(FluentIcons.refresh),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Button(
              style: ButtonStyle(
                backgroundColor: p.isUpdating || !p.localFilesModified
                    ? null
                    : ButtonState.all(
                        SystemTheme.accentColor.accent.toAccentColor(),
                      ),
              ),
              onPressed: p.isUpdating || !p.localFilesModified ? null : () => p.push(),
              child: const Row(
                children: [
                  Text('Push'),
                  Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(FluentIcons.upload),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];

    // Use transparent container to disable error sound on click
    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: mat.CircularProgressIndicator(
                    value: p.isUpdating ? null : 0,
                    color: SystemTheme.accentColor.accent.toAccentColor(),
                    strokeWidth: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.settings),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (b) => SettingsPage(
                        provider: Provider.of<GitProvider>(context, listen: false),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ChangeNotifierProvider(
                  create: (context) => logState,
                  child: AnimatedList(
                    controller: LogState.logListScrollController,
                    reverse: true,
                    shrinkWrap: true,
                    key: LogState.logListKey,
                    itemBuilder: (context, index, animation) => Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        textAlign: TextAlign.left,
                        LogState.logs[index].$1,
                        style: TextStyle(
                          color: LogState.logs[index].$2.withOpacity(index == LogState.logs.length - 1 ? 1 : 0.5),
                        ),
                      ),
                    ),
                    initialItemCount: LogState.logs.length > 5 ? 5 : LogState.logs.length,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
