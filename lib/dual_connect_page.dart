// lib/dual_connect_page.dart

import 'package:flutter/material.dart';
import 'services/freebuds_service.dart';
import 'dart:async';

class DualConnectPage extends StatefulWidget {
  const DualConnectPage({super.key});

  @override
  State<DualConnectPage> createState() => _DualConnectPageState();
}

class _DualConnectPageState extends State<DualConnectPage> {
  List<Map<String, dynamic>>? _devices;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final devices = await FreeBudsService.getDualConnectDevices();
    if (mounted) {
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    }
  }

  Future<void> _performAction(String mac, int code) async {
    setState(() => _isLoading = true);
    await FreeBudsService.dualConnectAction(mac, code);
    // Give the device a moment to process the action before refreshing
    await Future.delayed(const Duration(milliseconds: 1500));
    await _loadDevices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dual Connection')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices == null
          ? const Center(child: Text('Failed to load device list.'))
          : RefreshIndicator(
        onRefresh: _loadDevices,
        child: ListView.builder(
          itemCount: _devices!.length,
          itemBuilder: (context, index) {
            final device = _devices![index];
            return _buildDeviceTile(device);
          },
        ),
      ),
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> device) {
    final String name = device['name'];
    final String mac = device['mac_address'];
    final bool isConnected = device['is_connected'];
    final bool isPlaying = device['is_playing'];

    String statusText = 'Available';
    Color statusColor = Colors.grey;
    if (isPlaying) {
      statusText = 'Connected, Playing';
      statusColor = Colors.green;
    } else if (isConnected) {
      statusText = 'Connected';
      statusColor = Colors.blue;
    }

    // --- THIS IS THE NEW, IMPROVED LAYOUT ---
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        child: Row(
          children: [
            // --- FIX 2A: The Centered Icon ---
            // The icon is now the first element in the Row, so it will be vertically centered by default.
            Icon(Icons.phone_android, color: isConnected ? Theme
                .of(context)
                .colorScheme
                .primary : Colors.grey, size: 36),
            const SizedBox(width: 16),

            // --- FIX 2B: The Flexible Text Section ---
            // Expanded allows the text column to take all available horizontal space, pushing the button to the end.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(mac, style: Theme
                      .of(context)
                      .textTheme
                      .bodySmall),
                  const SizedBox(height: 4),
                  Text(statusText, style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // --- FIX 2C: The Centered Button ---
            // The button is now the last element, and the Row will center it vertically relative to the other content.
            isConnected
                ? ElevatedButton(
              onPressed: () => _performAction(mac, 2), // 2 = disconnect
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme
                    .of(context)
                    .colorScheme
                    .error,
                foregroundColor: Theme
                    .of(context)
                    .colorScheme
                    .onError,
              ),
              child: const Text('Disconnect'),
            )
                : OutlinedButton(
              onPressed: () => _performAction(mac, 1), // 1 = connect
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}