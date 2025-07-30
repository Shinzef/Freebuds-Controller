// lib/gesture_settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'services/freebuds_service.dart';

// Constants class remains the same
class GestureSettingsConstants {
  static const Map<int, String> tapActions = {
    1: 'Play/Pause',
    2: 'Next Track',
    7: 'Previous Track',
    0: 'Voice Assistant',
    -1: 'Off',
  };

  static const Map<int, String> longPressActions = {
    10: 'Switch Noise Cancellation',
    -1: 'Off',
  };

  static const Map<int, String> swipeActions = {
    8: 'Adjust Volume',
    -1: 'Off',
  };
}

class GestureSettingsPage extends StatefulWidget {
  const GestureSettingsPage({super.key});

  @override
  State<GestureSettingsPage> createState() => _GestureSettingsPageState();
}

class _GestureSettingsPageState extends State<GestureSettingsPage> {
  late Future<Map<String, dynamic>?> _settingsFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Wait for the page transition to complete before loading data
    _settingsFuture = _loadInitialSettings();
  }

  /// Optimized loading that waits for the page transition to complete
  Future<Map<String, dynamic>?> _loadInitialSettings() async {
    // Wait for the current frame to complete and the page transition to start
    await SchedulerBinding.instance.endOfFrame;

    // Additional delay to ensure smooth transition, especially on Windows
    await Future.delayed(const Duration(milliseconds: 450));

    // Force the UI to rebuild with the loading state before making the Bluetooth call
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // Give the UI one more frame to render the loading state
    await SchedulerBinding.instance.endOfFrame;

    try {
      // Now make the Bluetooth call
      return await FreeBudsService.getGestureSettings();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Optimized refresh that prevents multiple simultaneous calls
  void _refreshSettings() {
    if (!mounted || _isLoading) return;

    setState(() {
      _isLoading = true;
      _settingsFuture = _performRefresh();
    });
  }

  /// Separate method for refresh to handle loading state
  Future<Map<String, dynamic>?> _performRefresh() async {
    // Give the UI a chance to render the loading state
    await SchedulerBinding.instance.endOfFrame;

    try {
      final result = await FreeBudsService.getGestureSettings();
      return result;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Optimized setting change handler with debouncing
  Future<void> _handleSettingChange(Future<void> Function() serviceCall) async {
    if (_isLoading) return; // Prevent multiple simultaneous calls

    setState(() {
      _isLoading = true;
    });

    // Give the UI a chance to render the loading state
    await SchedulerBinding.instance.endOfFrame;

    try {
      await serviceCall();
      // Small delay to ensure the setting is applied
      await Future.delayed(const Duration(milliseconds: 200));

      // Refresh settings
      if (mounted) {
        final newSettings = await FreeBudsService.getGestureSettings();
        setState(() {
          _settingsFuture = Future.value(newSettings);
        });
      }
    } catch (e) {
      // Handle error appropriately
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update setting: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gesture Controls'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          // Show loading indicator while waiting
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading gesture settings...'),
                ],
              ),
            );
          }

          // Handle error state
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  const Text('Failed to load gesture settings.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _refreshSettings,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Build the main UI
          final gestureSettings = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refreshSettings(),
            child: ListView(
              padding: const EdgeInsets.all(8.0),
              physics:
                  const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works
              children: [
                _buildGestureGroup(
                  title: 'Double-Tap',
                  settings: gestureSettings,
                  leftActionKey: 'double_tap_left',
                  rightActionKey: 'double_tap_right',
                  actionsMap: GestureSettingsConstants.tapActions,
                  onChanged: (side, action) {
                    _handleSettingChange(
                        () => FreeBudsService.setDoubleTapAction(side, action));
                  },
                ),
                _buildGestureGroup(
                  title: 'Triple-Tap',
                  settings: gestureSettings,
                  leftActionKey: 'triple_tap_left',
                  rightActionKey: 'triple_tap_right',
                  actionsMap: GestureSettingsConstants.tapActions,
                  onChanged: (side, action) {
                    _handleSettingChange(
                        () => FreeBudsService.setTripleTapAction(side, action));
                  },
                ),
                _buildGestureGroup(
                  title: 'Press & Hold',
                  settings: gestureSettings,
                  leftActionKey: 'long_tap_left',
                  rightActionKey: 'long_tap_right',
                  actionsMap: GestureSettingsConstants.longPressActions,
                  onChanged: (side, action) {
                    _handleSettingChange(
                        () => FreeBudsService.setLongTapAction(side, action));
                  },
                ),
                _buildSingleGestureControl(
                  title: 'Swipe',
                  settings: gestureSettings,
                  actionKey: 'swipe_action',
                  actionsMap: GestureSettingsConstants.swipeActions,
                  onChanged: (action) {
                    _handleSettingChange(
                        () => FreeBudsService.setSwipeAction(action));
                  },
                ),
                // Add some bottom padding for better UX
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI HELPER WIDGETS ---

  Widget _buildGestureGroup({
    required String title,
    required Map<String, dynamic> settings,
    required String leftActionKey,
    required String rightActionKey,
    required Map<int, String> actionsMap,
    required Function(int side, int action) onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            _buildDropdown(
              'Left Earbud',
              settings[leftActionKey] ?? -1,
              actionsMap,
              _isLoading ? null : (action) => onChanged(0, action),
            ),
            _buildDropdown(
              'Right Earbud',
              settings[rightActionKey] ?? -1,
              actionsMap,
              _isLoading ? null : (action) => onChanged(1, action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleGestureControl({
    required String title,
    required Map<String, dynamic> settings,
    required String actionKey,
    required Map<int, String> actionsMap,
    required Function(int action) onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            _buildDropdown(
              'Action',
              settings[actionKey] ?? -1,
              actionsMap,
              _isLoading ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    int currentValue,
    Map<int, String> actionsMap,
    ValueChanged<int>? onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        DropdownButton<int>(
          value: actionsMap.containsKey(currentValue) ? currentValue : null,
          hint: const Text("Unknown"),
          items: actionsMap.entries.map((entry) {
            return DropdownMenuItem<int>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: onChanged == null
              ? null
              : (int? newValue) {
                  if (newValue != null) {
                    onChanged(newValue);
                  }
                },
        ),
      ],
    );
  }
}