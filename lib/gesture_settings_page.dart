import 'package:flutter/material.dart';
import 'services/freebuds_service.dart';

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
  Map<String, dynamic>? _gestureSettings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Avoid showing the loader for quick refreshes
    if (_gestureSettings == null) {
      setState(() => _isLoading = true);
    }

    final settings = await FreeBudsService.getGestureSettings();

    if (mounted) {
      setState(() {
        _gestureSettings = settings;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gesture Controls')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _gestureSettings == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Failed to load gesture settings.'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadSettings, child: const Text('Retry'))
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadSettings,
        child: ListView(
          padding: const EdgeInsets.all(8.0),
          children: [
            _buildGestureGroup(
              title: 'Double-Tap',
              leftActionKey: 'double_tap_left',
              rightActionKey: 'double_tap_right',
              actionsMap: GestureSettingsConstants.tapActions,
              onChanged: (side, action) => FreeBudsService.setDoubleTapAction(side, action).then((_) => _loadSettings()),
            ),
            _buildGestureGroup(
              title: 'Triple-Tap',
              leftActionKey: 'triple_tap_left',
              rightActionKey: 'triple_tap_right',
              actionsMap: GestureSettingsConstants.tapActions,
              onChanged: (side, action) => FreeBudsService.setTripleTapAction(side, action).then((_) => _loadSettings()),
            ),
            _buildGestureGroup(
              title: 'Press & Hold',
              leftActionKey: 'long_tap_left',
              rightActionKey: 'long_tap_right',
              actionsMap: GestureSettingsConstants.longPressActions,
              onChanged: (side, action) => FreeBudsService.setLongTapAction(side, action).then((_) => _loadSettings()),
            ),
            _buildSingleGestureControl(
              title: 'Swipe',
              actionKey: 'swipe_action',
              actionsMap: GestureSettingsConstants.swipeActions,
              onChanged: (action) => FreeBudsService.setSwipeAction(action).then((_) => _loadSettings()),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGestureGroup({
    required String title,
    required String leftActionKey,
    required String rightActionKey,
    required Map<int, String> actionsMap,
    required Function(int side, int action) onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            // --- FIX 1: Pass the correct key ---
            _buildDropdown('Left Earbud', leftActionKey, _gestureSettings![leftActionKey], actionsMap, (action) => onChanged(0, action)),
            _buildDropdown('Right Earbud', rightActionKey, _gestureSettings![rightActionKey], actionsMap, (action) => onChanged(1, action)),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleGestureControl({
    required String title,
    required String actionKey,
    required Map<int, String> actionsMap,
    required Function(int action) onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            // --- FIX 2: Pass the correct key ---
            _buildDropdown('Action', actionKey, _gestureSettings![actionKey], actionsMap, (action) => onChanged(action)),
          ],
        ),
      ),
    );
  }

  // --- FIX 3: Updated method signature and setState logic ---
  Widget _buildDropdown(String label, String stateKey, int currentValue, Map<int, String> actionsMap, ValueChanged<int> onChanged) {
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
              // Optimistically update the UI before calling the service
              setState(() {
                _gestureSettings![stateKey] = newValue;
              });
              // Then, send the command to the device
              onChanged(newValue);
            }
          },
        ),
      ],
    );
  }
}