import 'dart:async';
import 'dart:io';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'services/freebuds_service.dart';
import 'gesture_settings_page.dart';
import 'equalizer_page.dart';
import 'dual_connect_page.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'services/theme_service.dart';
import 'settings_page.dart';
import 'platform_services.dart' as ps;
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

// NEW ANC UI DATA
class AncLevelInfo {
  const AncLevelInfo(this.title, this.subtitle, {this.icon, this.strength});
  final String title;
  final String subtitle;
  final IconData? icon;
  final double? strength;
}

const Map<int, AncLevelInfo> _ancLevelsData = {
  0: AncLevelInfo('Comfortable', 'Light filtering for comfort', strength: 0.33),
  1: AncLevelInfo('Normal', 'Balanced noise reduction', strength: 0.66),
  2: AncLevelInfo('Ultra', 'Maximum isolation', strength: 1.0),
  3: AncLevelInfo('Dynamic', 'AI-powered adaptive filtering', icon: Icons.flash_on_rounded),
};

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
    await ps.PlatformServices.initialize();
    appWindow.show();
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final lightColorScheme = ColorScheme.fromSeed(
          seedColor: themeService.accentColor,
          brightness: Brightness.light,
        );
        final darkColorScheme = ColorScheme.fromSeed(
          seedColor: themeService.accentColor,
          brightness: Brightness.dark,
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FreeBuds Controller',
          theme: ThemeData(
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor:
                Platform.isWindows ? const Color.fromARGB(0, 0, 0, 0) : null,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor:
                Platform.isWindows ? Colors.transparent : null,
            useMaterial3: true,
          ),
          themeMode: themeService.themeMode,
          home: Platform.isWindows
              ? WindowBorder(
                  color: Colors.transparent,
                  width: 0,
                  child: const FreeBudsController(),
                )
              : const FreeBudsController(),
        );
      },
    );
  }
}

class FreeBudsController extends StatefulWidget {
  const FreeBudsController({super.key});

  @override
  _FreeBudsControllerState createState() => _FreeBudsControllerState();
}

class _FreeBudsControllerState extends State<FreeBudsController>
    with TickerProviderStateMixin, WidgetsBindingObserver, WindowListener {
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

  // Animation variables
  late AnimationController _connectionAnimationController;
  late Animation<double> _batteryCardAnimation;
  late Animation<double> _ancCardAnimation;
  late Animation<double> _settingsCardAnimation;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    // Animation setup
    _connectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Staggered animations for cards
    _batteryCardAnimation = CurvedAnimation(
        parent: _connectionAnimationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut));
    _ancCardAnimation = CurvedAnimation(
        parent: _connectionAnimationController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOut));
    _settingsCardAnimation = CurvedAnimation(
        parent: _connectionAnimationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut));
    _fabAnimation = CurvedAnimation(
        parent: _connectionAnimationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut));

    _checkConnection();

    if (Platform.isWindows) {
      WidgetsBinding.instance.addObserver(this);
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      WidgetsBinding.instance.removeObserver(this);
      windowManager.removeListener(this);
    }
    _ancUpdateTimer?.cancel();
    _connectionAnimationController.dispose();
    super.dispose();
  }

  // Debounced ANC update method
  void _debouncedAncUpdate() {
    _ancUpdateTimer?.cancel();
    _ancUpdateTimer = Timer(const Duration(milliseconds: 300), () {
      _updateAncStatusOnly();
    });
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
      _connectionAnimationController.reset();
      _connectionAnimationController.forward();
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
          // Clear previous data to avoid showing stale info
          _batteryInfo = null;
          _ancStatus = null;
        });

        // Start the animation immediately
        _connectionAnimationController.reset();
        _connectionAnimationController.forward();

        // Show connection notification
        ps.PlatformServices.showConnectionNotification(true, "HUAWEI FreeBuds 6i");

        // Fetch status in the background without blocking the UI
        _updateAllDeviceStatus();
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

    // Reset animation
    _connectionAnimationController.reset();

    // Show disconnection notification
    ps.PlatformServices.showConnectionNotification(false, "HUAWEI FreeBuds 6i");
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
    final isWide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor:
          Platform.isWindows ? Colors.transparent : Theme.of(context).colorScheme.surface,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const SettingsPage()));
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateAllDeviceStatus,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24.0, 24.0, 24.0, _isConnected ? 30.0 : 0.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 700) {
                return _buildWideLayout();
              } else {
                return _buildNarrowLayout();
              }
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isConnected
          ? FadeTransition(
              opacity: _fabAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.equalizer),
                      label: const Text('Equalizer'),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const EqualizerPage()));
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.gesture),
                      label: const Text('Gestures'),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) =>
                                const GestureSettingsPage()));
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.devices_other),
                      label: const Text('Dual Connect'),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const DualConnectPage()));
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null, // No floating action button when not connected
    );
  }

  Widget _buildWideLayout() {
    const spacing = 24.0;
    // If not connected, only show the connection card.
    if (!_isConnected) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 450, // Constrain width for a better look
            height: 200, // Constrain height to prevent vertical stretching
            child: _buildConnectionCard(),
          ),
        ],
      );
    }
    // If connected, show the full bento layout.
    return SingleChildScrollView(
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 1,
                  child: _buildConnectionCard(),
                ),
                SizedBox(width: spacing),
                Expanded(
                  flex: 2,
                  child:
                      _buildAnimatedCard(_batteryCardAnimation, _buildBatteryCard()),
                ),
              ],
            ),
          ),
          SizedBox(height: spacing),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildAnimatedCard(_ancCardAnimation, _buildAncCard()),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildAnimatedCard(
                      _settingsCardAnimation, _buildSettingsCard()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    const spacing = 24.0;
    return ListView(
      children: [
        _buildConnectionCard(),
        const SizedBox(height: spacing),
        if (_isConnected) ...[
          _buildAnimatedCard(_batteryCardAnimation, _buildBatteryCard()),
          const SizedBox(height: spacing),
          _buildAnimatedCard(_ancCardAnimation, _buildAncCard()),
          const SizedBox(height: spacing),
          _buildAnimatedCard(_settingsCardAnimation, _buildSettingsCard()),
        ],
      ],
    );
  }

  Widget _buildAnimatedCard(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildConnectionCard() {
    Widget content;
    Key? key;

    // Determine content and key based on state for AnimatedSwitcher
    if (_isLoading && !_isConnected) {
      key = const ValueKey('loading-connect');
      content = const Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: CircularProgressIndicator()));
    } else if (!_isConnected) {
      key = const ValueKey('disconnected');
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, // To center the button
        children: [
          const SizedBox(height: 12),
          const Center(child: Text("You are not connected to a device.")),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _connect,
            child: const Text('Connect'),
          ),
        ],
      );
    } else if (_deviceInfo == null) {
      key = const ValueKey('loading-info');
      content = const Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: CircularProgressIndicator()));
    } else if (_deviceInfo!['error'] != null) {
      key = const ValueKey('error');
      content = Center(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Text("Error: ${_deviceInfo!['error']}",
                  style:
                  TextStyle(color: Theme.of(context).colorScheme.error))));
    } else {
      // This is the main connected state.
      key = const ValueKey('connected');
      final model = _deviceInfo!['model'] ?? 'Unknown Model';
      final firmware = _deviceInfo!['firmware_version'] ?? 'N/A';
      final serial = _deviceInfo!['serial_number'] ?? 'N/A';
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(model,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('Firmware: $firmware',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70)),
                const SizedBox(height: 4),
                Text('Serial: $serial',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _disconnect,
            style: ElevatedButton.styleFrom(
              backgroundColor:
              Theme.of(context).colorScheme.error.withOpacity(0.6),
              foregroundColor: Theme.of(context).colorScheme.onError,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Disconnect'),
          ),
        ],
      );
    }

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth_connected_rounded,
                    size: 28,
                    color: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.color
                        ?.withOpacity(0.8)),
                const SizedBox(width: 12),
                Text('Connection', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const Divider(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(key: key, child: content),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDER METHODS ---

  Widget _buildAncCard() {
    final currentMode = _ancStatus?['mode'] ?? 0;
    final currentLevel = _ancStatus?['level'] ?? 0;

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.volume_up_rounded, size: 28, color: Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.8)),
                const SizedBox(width: 12),
                Text('Noise Control', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const Divider(height: 24),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Off'), icon: Icon(Icons.volume_off_rounded, size: 18)),
                ButtonSegment(value: 1, label: Text('On'), icon: Icon(Icons.volume_up_rounded, size: 18)),
                ButtonSegment(value: 2, label: Text('Aware'), icon: Icon(Icons.hearing_rounded, size: 18)),
              ],
              selected: {currentMode},
              onSelectionChanged: (newSelection) {
                if (newSelection.first != currentMode) {
                  _setAncMode(newSelection.first);
                }
              },
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.2),
                foregroundColor: Colors.white.withOpacity(0.8),
                selectedBackgroundColor: Theme.of(context).colorScheme.primary,
                selectedForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (currentMode == 1) ...[
              const Divider(height: 32),
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text('Intensity Level', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              ..._ancLevelsData.entries.map((entry) {
                final int key = entry.key;
                final AncLevelInfo data = entry.value;
                final bool isSelected = currentLevel == key;

                return InkWell(
                  onTap: () => isSelected ? null : _setAncLevel(key),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.25) : Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(data.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (data.icon != null) ...[
                                    const SizedBox(width: 6),
                                    Icon(data.icon, size: 16, color: Colors.orangeAccent),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(data.subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                            ],
                          ),
                        ),
                        if (data.strength != null) _buildAncStrengthIndicator(data.strength!),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (currentMode == 2) ...[
              const Divider(height: 24),
              SwitchListTile(
                title: const Text('Voice Boost'),
                subtitle: const Text('Enhanced voice clarity'),
                value: currentLevel == 1,
                onChanged: (value) => _setAncLevel(value ? AncLevelConstants.voiceBoost : AncLevelConstants.normalAwareness),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAncStrengthIndicator(double strength) {
    return SizedBox(
      width: 50,
      height: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: strength,
          backgroundColor: Colors.white.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildBatteryCard() => GlassmorphicCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.battery_std_rounded,
                    size: 28,
                    color: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.color
                        ?.withOpacity(0.8),
                  ),
                  const SizedBox(width: 12),
                  Text('Battery Status',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                      child:
                          _buildBatteryInfoBox('Left', _batteryInfo?['left'])),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          _buildBatteryInfoBox('Right', _batteryInfo?['right'])),
                ],
              ),
              const SizedBox(height: 12),
              _buildBatteryInfoBox('Charging Case', _batteryInfo?['case']),
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
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 28, color: Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.8)),
              const SizedBox(width: 12),
              Text('Device Settings', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const Divider(height: 24),
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
        ],
      ),
    ),
  );

  Widget _buildBatteryInfoBox(String label, int? level) {
    final color = level == null
        ? Colors.grey
        : level > 50
            ? Theme.of(context).colorScheme.primary
            : level > 20
                ? Colors.amber
                : Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(level != null ? '$level%' : '--%',
                  style: TextStyle(color: Colors.white.withOpacity(0.7))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: level != null ? level / 100.0 : 0.0,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
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
        CloseWindowButton(
          colors: buttonColors,
          onPressed: () => windowManager.hide(),
        ),
      ],
    );
  }
}