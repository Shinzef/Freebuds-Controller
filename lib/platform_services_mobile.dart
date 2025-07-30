// lib/platform_services_mobile.dart
import 'package:flutter/material.dart';

// This is the stub implementation for mobile platforms (Android, iOS)
class PlatformServices {
  static Future<void> initialize() async {
    // No-op on mobile
  }

  static void showConnectionNotification(bool isConnected, String deviceName) {
    // No-op on mobile
  }
}

// Stub implementation for WindowListener
mixin WindowListener {}

// Stub implementation for WindowButtons
class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// Stub implementation for DragToMoveArea
class DragToMoveArea extends StatelessWidget {
  final Widget child;
  const DragToMoveArea({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
} 