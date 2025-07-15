import 'package:flutter/material.dart';
import 'services/freebuds_service.dart';

// These constants are used to map the integer codes from the device
// to human-readable strings for the UI.
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
  // This state variable will hold the Future that fetches our settings.
  // We initialize it in initState() and the FutureBuilder will handle the rest.
  late Future<Map<String, dynamic>?> _settingsFuture;

  @override
  void initState() {
    super.initState();
    // Start loading the data when the page is first created.
    _settingsFuture = _loadInitialSettings();
  }

  /// THE CORE FIX: This method ensures the heavy Bluetooth call happens
  /// *after* the page transition has started, preventing the UI from freezing.
  Future<Map<String, dynamic>?> _loadInitialSettings() async {
    // This tiny delay gives Flutter enough time to start the page slide animation.
    await Future.delayed(const Duration(milliseconds: 50));
    // Now, we make the actual call to get the data.
    return FreeBudsService.getGestureSettings();
  }

  /// Call this method to fetch the latest settings from the device again.
  /// It updates the `_settingsFuture` and tells the UI to rebuild.
  void _refreshSettings() {
    setState(() {
      _settingsFuture = FreeBudsService.getGestureSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gesture Controls')),
      body: FutureBuilder<Map<String, dynamic>?>(
        // The FutureBuilder widget listens to our _settingsFuture.
        future: _settingsFuture,
        builder: (context, snapshot) {
          // --- STATE 1: LOADING ---
          // While the future is running, we show a loading spinner.
          // This is what the user sees during the smooth page transition.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- STATE 2: ERROR ---
          // If the future completes with an error or no data, we show an error message.
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Failed to load gesture settings.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _refreshSettings, // Allow user to retry
                    child: const Text('Retry'),
                  )
                ],
              ),
            );
          }

          // --- STATE 3: SUCCESS ---
          // If we get here, the data has loaded successfully.
          final gestureSettings = snapshot.data!;

          // Now we build the actual UI with the data we received.
          return RefreshIndicator(
            onRefresh: () async => _refreshSettings(),
            child: ListView(
              padding: const EdgeInsets.all(8.0),
              children: [
                _buildGestureGroup(
                  title: 'Double-Tap',
                  settings: gestureSettings,
                  leftActionKey: 'double_tap_left',
                  rightActionKey: 'double_tap_right',
                  actionsMap: GestureSettingsConstants.tapActions,
                  onChanged: (side, action) {
                    // When a setting is changed, we call the service and then refresh.
                    FreeBudsService.setDoubleTapAction(side, action)
                        .then((_) => _refreshSettings());
                  },
                ),
                _buildGestureGroup(
                  title: 'Triple-Tap',
                  settings: gestureSettings,
                  leftActionKey: 'triple_tap_left',
                  rightActionKey: 'triple_tap_right',
                  actionsMap: GestureSettingsConstants.tapActions,
                  onChanged: (side, action) {
                    FreeBudsService.setTripleTapAction(side, action)
                        .then((_) => _refreshSettings());
                  },
                ),
                _buildGestureGroup(
                  title: 'Press & Hold',
                  settings: gestureSettings,
                  leftActionKey: 'long_tap_left',
                  rightActionKey: 'long_tap_right',
                  actionsMap: GestureSettingsConstants.longPressActions,
                  onChanged: (side, action) {
                    FreeBudsService.setLongTapAction(side, action)
                        .then((_) => _refreshSettings());
                  },
                ),
                _buildSingleGestureControl(
                  title: 'Swipe',
                  settings: gestureSettings,
                  actionKey: 'swipe_action',
                  actionsMap: GestureSettingsConstants.swipeActions,
                  onChanged: (action) {
                    FreeBudsService.setSwipeAction(action)
                        .then((_) => _refreshSettings());
                  },
                )
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
                'Left Earbud', settings[leftActionKey], actionsMap, (action) => onChanged(0, action)),
            _buildDropdown(
                'Right Earbud', settings[rightActionKey], actionsMap, (action) => onChanged(1, action)),
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
            _buildDropdown('Action', settings[actionKey], actionsMap, onChanged),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
      String label, int currentValue, Map<int, String> actionsMap, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        DropdownButton<int>(
          value: currentValue,
          items: actionsMap.entries.map((entry) {
            return DropdownMenuItem<int>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null && newValue != currentValue) {
              // We call the onChanged callback passed from the build method.
              // This is what triggers the FreeBudsService call and the subsequent refresh.
              onChanged(newValue);
            }
          },
        ),
      ],
    );
  }
}