import 'package:flutter/material.dart';
import 'dart:async';
import 'services/freebuds_service.dart'; // Import the service
import 'gesture_settings_page.dart';
import 'equalizer_page.dart';

// Add a class for constants to avoid magic numbers in the code.
class AncLevelConstants {
  // These values correspond to the integer codes expected by the JNI layer.
  static const int comfortable = 0;
  static const int normal = 1;
  static const int ultra = 2;
  static const int dynamic = 3;
  static const int voiceBoost = 4;
  // static const int level5_unused = 5;
  static const int normalAwareness = 6;
}

class GestureSettingsConstants {
  static const Map<int, String> actions = {
    1: 'Play/Pause',
    2: 'Next Track',
    7: 'Previous Track',
    0: 'Voice Assistant',
    -1: 'Off',
    8: 'Adjust Volume', // Swipe only
    10: 'Switch Noise Cancellation', // Long press only
  };

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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreeBuds Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const FreeBudsController(),
    );
  }
}

class FreeBudsController extends StatefulWidget {
  const FreeBudsController({super.key});

  @override
  _FreeBudsControllerState createState() => _FreeBudsControllerState();
}

class _FreeBudsControllerState extends State<FreeBudsController> {
  // State variables
  bool _isLoading = false;
  bool _isConnected = false;
  String _deviceInfo = "Not connected";
  Map<String, dynamic>? _batteryInfo;
  bool _isWearDetectionEnabled = false;
  bool _isLowLatencyEnabled = false;
  int _soundQualityPreference = 0;
  Map<String, dynamic>? _ancStatus;
  Timer? _ancUpdateTimer;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  // Debounced ANC update method
  void _debouncedAncUpdate() {
    _ancUpdateTimer?.cancel();
    _ancUpdateTimer = Timer(const Duration(milliseconds: 300), () {
      _updateAncStatusOnly();
    });
  }

  @override
  void dispose() {
    _ancUpdateTimer?.cancel();
    super.dispose();
  }


  // --- Core Data Fetching Logic ---

  Future<void> _updateAllDeviceStatus() async {
  if (!_isConnected || !mounted) return;

  // Only set loading for full updates
  setState(() => _isLoading = true);

  try {
    final results = await Future.wait([
      FreeBudsService.getDeviceInfo(),
      FreeBudsService.getBatteryInfo(),
      FreeBudsService.getWearDetection(),
      FreeBudsService.getLowLatency(),
      FreeBudsService.getSoundQuality(),
      FreeBudsService.getAncStatus(),
    ]);

    if (!mounted) return;
    setState(() {
      _deviceInfo = results[0] as String? ?? "Unknown Device";
      _batteryInfo = results[1] as Map<String, dynamic>?;
      _isWearDetectionEnabled = results[2] as bool;
      _isLowLatencyEnabled = results[3] as bool;
      _soundQualityPreference = results[4] as int;
      _ancStatus = results[5] as Map<String, dynamic>?;
    });
  } catch (e) {
    print("Error updating all device status: $e");
    _showErrorSnackBar('Error updating settings: $e');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // --- Connection Handlers ---

  Future<void> _checkConnection() async {
    setState(() => _isLoading = true);
    final connected = await FreeBudsService.isConnected();
    setState(() => _isConnected = connected);

    if (_isConnected) {
      await Future.delayed(const Duration(milliseconds: 750));
      await _updateAllDeviceStatus();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connect() async {
    setState(() => _isLoading = true);
    try {
      final success = await FreeBudsService.connectDevice();
      setState(() => _isConnected = success);
      if (success) {
        await Future.delayed(const Duration(milliseconds: 750));
        await _updateAllDeviceStatus();
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to connect');
      }
    } catch (e) {
      print('Connection error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    await FreeBudsService.disconnectDevice();
    setState(() {
      _isConnected = false;
      _deviceInfo = "Not connected";
      _batteryInfo = null;
      _ancStatus = null;
      _isLoading = false;
    });
  }

  // --- Feature Setters ---

      Future<void> _setAncMode(int mode) async {
      try {
        // Set loading state to prevent UI flickering
        setState(() => _isLoading = true);

        final success = await FreeBudsService.setAncMode(mode);
        if (success) {
          // Give the device time to process the command
          await Future.delayed(const Duration(milliseconds: 500));

          // Only update ANC status instead of all device status
          await _updateAncStatusOnly();
        } else {
          _showErrorSnackBar('Failed to set ANC mode');
        }
      } catch (e) {
        _showErrorSnackBar('Error setting ANC mode: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }

   Future<void> _setAncLevel(int level) async {
  try {
    print('Setting ANC level to: $level');
    final success = await FreeBudsService.setAncLevel(level);
    if (success) {
      // Longer delay for awareness mode changes
      await Future.delayed(const Duration(milliseconds: 800));
      await _updateAncStatusOnly();
    } else {
      _showErrorSnackBar('Failed to set ANC level');
    }
  } catch (e) {
    _showErrorSnackBar('Error setting ANC level: $e');
  }
}

Future<void> _updateAncStatusOnly() async {
  if (!_isConnected || !mounted) return;

  try {
    final ancStatus = await FreeBudsService.getAncStatus();
    print('Received ANC status: $ancStatus'); // Add this debug line
    if (mounted) {
      setState(() {
        _ancStatus = ancStatus;
      });
    }
  } catch (e) {
    print("Error updating ANC status: $e");
  }
}

  Future<void> _onWearDetectionChanged(bool value) async {
    if (await FreeBudsService.setWearDetection(value)) setState(() => _isWearDetectionEnabled = value);
  }

  Future<void> _onLowLatencyChanged(bool value) async {
    if (await FreeBudsService.setLowLatency(value)) setState(() => _isLowLatencyEnabled = value);
  }

  Future<void> _onSoundQualityChanged(int? value) async {
    if (value == null) return;
    if (await FreeBudsService.setSoundQuality(value)) setState(() => _soundQualityPreference = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FreeBuds Controller'),
        actions: [
          if (_isConnected && !_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _updateAllDeviceStatus,
              tooltip: 'Refresh Status',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(8.0),
              children: [
                _buildConnectionCard(),
                if (_isConnected) ...[
                  _buildBatteryCard(),
                  _buildAncCard(),
                  _buildSettingsCard(),
                ],
              ],
            ),
    );
  }


  Widget _buildConnectionCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connection', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(_isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled, color: _isConnected ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(_deviceInfo, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(onPressed: _isConnected ? null : _connect, child: const Text('Connect')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _isConnected ? _disconnect : null, child: const Text('Disconnect')),
            ],
          ),
        ],
      ),
    ),
  );

   // --- WIDGET BUILDER METHODS ---

Widget _buildAncCard() {
  const cancellationLevels = { 0: 'Comfortable', 1: 'Normal', 2: 'Ultra', 3: 'Dynamic' };

  final currentMode = _ancStatus?['mode'] ?? 0;
  final currentLevel = _ancStatus?['level'] ?? 0;

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Noise Cancellation', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Off')),
              ButtonSegment(value: 1, label: Text('On')),
              ButtonSegment(value: 2, label: Text('Aware')),
            ],
            selected: {currentMode},
            onSelectionChanged: (newSelection) {
              if (newSelection.first != currentMode) {
                _setAncMode(newSelection.first);
              }
            },
          ),
          if (currentMode == 1) ...[
            const Divider(height: 24),
            Text('Cancellation Level', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: cancellationLevels.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: currentLevel == entry.key,
                  onSelected: (selected) {
                    if (selected && currentLevel != entry.key) {
                      _setAncLevel(entry.key);
                    }
                  },
                );
              }).toList(),
            )
          ],
          if (currentMode == 2) ...[
            const Divider(height: 24),
            SwitchListTile(
              title: const Text('Voice Boost'),
              subtitle: const Text('Enhanced voice clarity'),
              value: currentLevel == 1, // The getter logic returns 1 for voice boost, 0 for normal.
              onChanged: (value) {
                // --- IMPROVEMENT START ---
                // Use the new constants for clarity.
                _setAncLevel(value ? AncLevelConstants.voiceBoost : AncLevelConstants.normalAwareness);
                // --- IMPROVEMENT END ---
              },
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildBatteryCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Battery', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBatteryIndicator('Left', _batteryInfo?['left']),
              _buildBatteryIndicator('Right', _batteryInfo?['right']),
              _buildBatteryIndicator('Case', _batteryInfo?['case']),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildSettingsCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Wear Detection'),
            subtitle: const Text('Auto-pause music when removed'),
            value: _isWearDetectionEnabled,
            onChanged: _onWearDetectionChanged,
          ),
          SwitchListTile(
            title: const Text('Low Latency Mode'),
            subtitle: const Text('Reduces audio delay for gaming'),
            value: _isLowLatencyEnabled,
            onChanged: _onLowLatencyChanged,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
            child: Text('Sound Preference', style: Theme.of(context).textTheme.titleMedium),
          ),
          RadioListTile<int>(
            title: const Text('Prioritize Connection'), value: 0, groupValue: _soundQualityPreference, onChanged: _onSoundQualityChanged,
          ),
          RadioListTile<int>(
            title: const Text('Prioritize Sound Quality'), value: 1, groupValue: _soundQualityPreference, onChanged: _onSoundQualityChanged,
          ),
          const Divider(),
          ListTile(
            title: const Text('Gesture Controls'),
            subtitle: const Text('Customize tap and swipe actions'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GestureSettingsPage()));
            },
          ),
          ListTile(
            title: const Text('Equalizer'),
            subtitle: const Text('Adjust sound presets'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const EqualizerPage()));
            },
          ),
        ],
      ),
    ),
  );


  Widget _buildBatteryIndicator(String label, int? level) {
    if (level == null) {
      return Column(children: [Text(label), const SizedBox(height: 4), const Text('--%')]);
    }
    return Column(
      children: [
        Text(label),
        const SizedBox(height: 8),
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            value: level / 100.0,
            strokeWidth: 5,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              level > 50 ? Colors.green : level > 20 ? Colors.orange : Colors.red,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('$level%'),
      ],
    );
  }
}

