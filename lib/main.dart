import 'dart:async';
import 'dart:io';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';
import 'dart:ui';
import 'services/freebuds_service.dart'; // Import the service
import 'gesture_settings_page.dart';
import 'equalizer_page.dart';
import 'dual_connect_page.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:bitsdojo_window/bitsdojo_window.dart';



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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    doWhenWindowReady(() async {

      const initialSize = Size(900, 600);
      appWindow.minSize = Size(500, 400);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = "FreeBuds Controller";

      await flutter_acrylic.Window.initialize();
      await flutter_acrylic.Window.setEffect(
        effect: flutter_acrylic.WindowEffect.mica,
      );

      flutter_acrylic.Window.hideWindowControls();
      // this f thing made my life so f bad
      // i debugged ts why the controls are duplicated, not knowing it comes with its own.
      // worst part it doesnt even work. ( maybe thats my issue ).
      // but i didnt f expect it, since i thought its only for f mica.

      appWindow.show();

    });


  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final _defaultLightColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.green,
    brightness: Brightness.light,
    background: Colors.white,
  );

  static final _defaultDarkColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.green,
    brightness: Brightness.dark,
    background: Colors.black,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FreeBuds Controller',
      theme: ThemeData(
        colorScheme: _defaultLightColorScheme,
        scaffoldBackgroundColor:
        Platform.isWindows ? Colors.transparent : null,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: _defaultDarkColorScheme,
        scaffoldBackgroundColor:
        Platform.isWindows ? Colors.transparent : null,
        useMaterial3: true,
      ),
      // themeMode: ThemeMode.light,
      home: WindowBorder(
        color: Colors.transparent,
        width: 0,
        child: const FreeBudsController(),
      ),
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
  Map<String, dynamic>? _deviceInfo; // Now it's a map
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
        _deviceInfo = results[0] as Map<String, dynamic>?;
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
      final success = await FreeBudsService.connectDevice("HUAWEI FreeBuds 6i");

      if (success) {
        print("✅ CONNECTION SUCCEEDED. The native part is done.");
        setState(() {
          _isConnected = true;
          _isLoading = false; // Stop the loading indicator
          _deviceInfo = null;
        });

        // // Now, let's wait a moment and then fetch the status separately.
        // // This decouples the connection logic from the data fetching logic.
        // await Future.delayed(const Duration(seconds: 2));
        //
        // print("▶️ Two seconds have passed. Now attempting to update status...");
        await _updateAllDeviceStatus();
        // print("◀️ Status update finished.");

      } else {
        print("❌ CONNECTION FAILED. The native part returned false.");
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to connect. Please check device pairing.');
      }
      // --- END OF THE FIX ---

    } catch (e) {
      print('Connection error in Dart: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('An error occurred during connection: $e');
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    await FreeBudsService.disconnectDevice();
    setState(() {
      _isConnected = false;
      _deviceInfo = null;
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
    return WindowBorder(
        color: Colors.transparent,
        width: 0,
        child: Scaffold(
          // Transparent only on Windows (for acrylic/mica)
          backgroundColor: Platform.isWindows
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,

          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.black12,
            title: Platform.isWindows
                ? WindowTitleBarBox(
              child: Row(
                children: [
                  Expanded(
                    child: MoveWindow(
                      child: const Text(
                        "FreeBuds Controller",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const WindowButtons(),
                ],
              ),
            )
                : const Text("FreeBuds Controller"),
          ),

          body: Stack( // Use a Stack to layer the background and the content
            children: [
              // SafeArea ensures your UI avoids the system status bar and notches.
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0), // Main padding for the list
                  children: [
                    // This SizedBox provides the top padding that was missing.
                    const SizedBox(height: 60),

                    // Your existing cards will now sit perfectly inside this padded list.
                    _buildConnectionCard(),
                    const SizedBox(height: 16), // Spacing between cards
                    if (_isConnected) ...[
                      _buildBatteryCard(),
                      const SizedBox(height: 16),
                      _buildAncCard(),
                      const SizedBox(height: 16),
                      _buildSettingsCard(),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
      )
    );
  }


  Widget _buildConnectionCard() => GlassmorphicCard(
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
              Expanded(
                  child: Builder( // Using a Builder to cleanly handle the logic
                      builder: (context) {
                        if (!_isConnected || _deviceInfo == null) {
                          return const Text("Not connected");
                        }
                        if (_deviceInfo!['error'] != null) {
                          return Text("Error: ${_deviceInfo!['error']}");
                        }

                        final model = _deviceInfo!['model'] ?? 'Unknown Model';
                        final firmware = _deviceInfo!['firmware_version'] ?? 'N/A';
                        final serial = _deviceInfo!['serial_number'] ?? 'N/A';

                        return Text(
                          '$model\nFirmware: $firmware  |  Serial: $serial',
                          style: Theme.of(context).textTheme.bodyMedium,
                        );
                      }
                  )
              ),
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

    return GlassmorphicCard(
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
                  // Use the new constants for clarity.
                  _setAncLevel(value ? AncLevelConstants.voiceBoost : AncLevelConstants.normalAwareness);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryCard() => GlassmorphicCard( // <-- Use the new widget here
    child: Padding(
      padding: const EdgeInsets.all(20.0), // Increased padding for a better look
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add a subtle icon next to the title
          Row(
            children: [
              Icon(
                Icons.battery_charging_full_rounded,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Battery',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Ensure text is visible on the glass
                ),
              ),
            ],
          ),
          const SizedBox(height: 20), // Increased spacing
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

  Widget _buildSettingsCard() => GlassmorphicCard(
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
          const Divider(),
          ListTile(
            title: const Text('Connected Devices'),
            subtitle: const Text('Manage dual-device connection'),
            trailing: const Icon(Icons.devices_other),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DualConnectPage()));
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

class GlassmorphicCard extends StatelessWidget {
  final Widget child;

  const GlassmorphicCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0), // Slightly more blur
        child: Container(
          decoration: BoxDecoration(
            // --- THIS IS THE FIX FOR THE "GLOW" ---
            // Use a solid, semi-transparent color instead of a gradient.
            color: Colors.white.withOpacity(0.08),
            // --- END OF FIX ---
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: Colors.white.withOpacity(0.15), // Border is slightly more opaque
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // This ensures the background has a base color.
        Container(
          decoration: const BoxDecoration(
            color: Color(0xff1a1a2e), // A deep navy blue base
          ),
        ),
        // A blurred circle positioned in the top-left.
        Positioned(
          top: -100,
          left: -150,
          child: Container(
            height: 400,
            width: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.purple.withOpacity(0.5),
            ),
          ),
        ),
        // A second blurred circle positioned in the bottom-right.
        Positioned(
          bottom: -200,
          right: -150,
          child: Container(
            height: 500,
            width: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.5),
            ),
          ),
        ),
        // The blur effect that covers the entire screen, affecting the circles.
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 100.0, sigmaY: 100.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.1)),
          ),
        ),
      ],
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: Colors.white,
      mouseOver: Colors.white.withOpacity(0.2),
      mouseDown: Colors.white.withOpacity(0.4),
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: buttonColors),
      ],
    );
  }
}