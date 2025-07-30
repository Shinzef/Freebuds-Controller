// lib/platform_services_desktop.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:system_tray/system_tray.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:path/path.dart' as p;

// This is the real implementation for desktop platforms (Windows)
class PlatformServices {
  static final SystemTray _systemTray = SystemTray();
  static final Menu _menu = Menu();

  static Future<void> initialize() async {
    // Initialize flutter_acrylic
    await flutter_acrylic.Window.initialize();

    // Initialize bitsdojo_window
    doWhenWindowReady(() async {
      const initialSize = Size(900, 600);
      const minimumSize = Size(500, 400);
      appWindow.size = initialSize;
      appWindow.minSize = minimumSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = "FreeBuds Controller";

      // Apply Mica effect after window is ready
      await flutter_acrylic.Window.setEffect(
        effect: flutter_acrylic.WindowEffect.mica,
        dark: true,
      );

      flutter_acrylic.Window.hideWindowControls();

      appWindow.show();
    });

    // Initialize local_notifier
    await localNotifier.setup(
      appName: 'FreeBuds Controller',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );

    // Initialize system_tray
    final String iconPath = p.join(
      Directory.current.path,
      'windows',
      'runner',
      'resources',
      'app_icon.ico',
    );
    await _systemTray.initSystemTray(
      title: "FreeBuds Controller",
      iconPath: iconPath,
    );

    // Setup menu items
    await _menu.buildFrom([
      MenuItemLabel(
        label: 'Show',
        onClicked: (menuItem) async {
          appWindow.show();
          appWindow.restore();
          // appWindow.focus();
          await flutter_acrylic.Window.setEffect(
            effect: flutter_acrylic.WindowEffect.mica,
            dark: true,
          ); // Reapply Mica effect on show
        },
      ),
      MenuItemLabel(
        label: 'Hide',
        onClicked: (menuItem) async {
          appWindow.hide();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Exit',
        onClicked: (menuItem) async {
          appWindow.close();
        },
      ),
    ]);
    await _systemTray.setContextMenu(_menu);

    // Handle system tray events
    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        appWindow.show();
        appWindow.restore();
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
  }

  static void showConnectionNotification(bool isConnected, String deviceName) {
    LocalNotification notification = LocalNotification(
      title: isConnected ? 'Device Connected' : 'Device Disconnected',
      body: isConnected
          ? 'Connected to $deviceName'
          : 'Disconnected from $deviceName',
    );
    notification.show();
  }
}

// Re-exporting WindowListener for compatibility
mixin WindowListener on WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Default implementation, can be overridden.
  }

  void onWindowFocus() {}
  void onWindowBlur() {}
  void onWindowMaximize() {}
  void onWindowUnmaximize() {}
  void onWindowMinimize() {}
  void onWindowRestore() {}
  void onWindowResize() {}
  void onWindowMove() {}
  void onWindowEnterFullScreen() {}
  void onWindowLeaveFullScreen() {}
  void onWindowClose() {}
}

// Real implementation for WindowButtons
class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.minimize),
          onPressed: () => appWindow.minimize(),
          color: Colors.white,
        ),
        IconButton(
          icon: const Icon(Icons.crop_square),
          onPressed: () {
            if (appWindow.isMaximized) {
              appWindow.restore();
            } else {
              appWindow.maximize();
            }
          },
          color: Colors.white,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => appWindow.hide(),
          color: Colors.white,  
        ),
      ],
    );
  }
}

// Real implementation for DragToMoveArea
class DragToMoveArea extends StatelessWidget {
  final Widget child;
  const DragToMoveArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) => appWindow.startDragging(),
      child: child,
    );
  }
}