// lib/equalizer_page.dart

import 'package:flutter/material.dart';
import 'services/freebuds_service.dart';
import 'eq_editor_page.dart'; // <-- IMPORT OUR NEW EDITOR PAGE

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  Map<String, dynamic>? _eqInfo;
  bool _isLoading = true;

  static const int _symphonyId = 254;
  static const int _hifiLiveId = 253;
  static const Map<int, String> _fakePresetNames = {
    _symphonyId: 'Symphony',
    _hifiLiveId: 'Hi-Fi Live',
  };

  final Map<int, String> _presetNames = {
    0: 'Default', 1: 'Bass Boost', 2: 'Treble Boost', 3: 'Voices',
  };

  @override
  void initState() {
    super.initState();
    _loadEqInfo();
  }

  Future<void> _loadEqInfo({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) setState(() => _isLoading = true);

    final info = await FreeBudsService.getEqualizerInfo();

    if (info != null && info['custom_presets'] != null) {
      for (var preset in info['custom_presets']) {
        _presetNames[preset['id']] = preset['name'];
      }
    }

    if (mounted) {
      setState(() {
        _eqInfo = info;
        _isLoading = false;
      });
    }
  }

  Future<void> _onPresetChanged(int? newId) async {
    if (newId == null || !mounted) return;

    // Before setting a new preset, check if a fake preset was active and delete it.
    final customPresets = List<Map<dynamic, dynamic>>.from(_eqInfo!['custom_presets'] ?? []);
    final activeSymphony = customPresets.any((p) => p['id'] == _symphonyId);
    final activeHifi = customPresets.any((p) => p['id'] == _hifiLiveId);

    if (activeSymphony) {
      await FreeBudsService.deleteCustomEq(customPresets.firstWhere((p) => p['id'] == _symphonyId));
    }
    if (activeHifi) {
      await FreeBudsService.deleteCustomEq(customPresets.firstWhere((p) => p['id'] == _hifiLiveId));
    }

    setState(() => _eqInfo!['current_preset_id'] = newId);
    await FreeBudsService.setEqualizerPreset(newId);

    // Do a quick refresh to ensure the UI is in sync after potential deletions
    if (activeSymphony || activeHifi) {
      await _loadEqInfo(showLoader: false);
    }
  }

  Future<void> _showDeleteConfirmationDialog(Map<dynamic, dynamic> preset) async {
    final String name = preset['name'];
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text("Are you sure you want to delete the '$name' preset?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await FreeBudsService.deleteCustomEq(preset);
      await _loadEqInfo(showLoader: false);
    }
  }

  // --- THIS IS THE NEW NAVIGATION LOGIC ---
  Future<void> _navigateToEditor({Map<dynamic, dynamic>? preset}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => EqEditorPage(initialPreset: preset)),
    );
    // If the editor page popped with `true`, it means we saved, so we should refresh.
    if (result == true) {
      _loadEqInfo(showLoader: false);
    }
  }

  Future<void> _onFakePresetChanged(int fakeId) async {
    if (!mounted) return;

    final currentId = _eqInfo!['current_preset_id'];
    // If we're already on this preset, do nothing.
    if (currentId == fakeId) return;

    setState(() {
      _isLoading = true; // Show a loader for this multi-step process
    });

    // Check if the OTHER fake preset is active, and if so, delete it first.
    final otherFakeId = (fakeId == _symphonyId) ? _hifiLiveId : _symphonyId;
    final customPresets = List<Map<dynamic, dynamic>>.from(
        _eqInfo!['custom_presets'] ?? []);
    if (customPresets.any((p) => p['id'] == otherFakeId)) {
      await FreeBudsService.deleteCustomEq(
          customPresets.firstWhere((p) => p['id'] == otherFakeId));
    }

    final fakePresetType = (fakeId == _symphonyId) ? 0 : 1;
    await FreeBudsService.createFakePreset(fakePresetType, fakeId);

    // Finally, set the newly created preset as active.
    await FreeBudsService.setEqualizerPreset(fakeId);

    // Refresh the entire state from the device to ensure consistency.
    await _loadEqInfo(showLoader: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equalizer')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _eqInfo == null
          ? Center(child: Text('Failed to load settings.'))
          : RefreshIndicator(onRefresh: () => _loadEqInfo(), child: _buildPresetList()),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditor(), // Navigate to create a new preset
        child: const Icon(Icons.add),
        tooltip: 'Create Custom Preset',
      ),
    );
  }

  Widget _buildPresetList() {
    final int currentPresetId = _eqInfo!['current_preset_id'];
    final builtInIds = List<int>.from(_eqInfo!['built_in_preset_ids'] ?? []);
    final customPresets = List<Map<dynamic, dynamic>>.from(_eqInfo!['custom_presets'] ?? []);

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Built-in Presets', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: builtInIds.map((id) => ChoiceChip(
                    label: Text(_presetNames[id] ?? 'Preset $id'),
                    selected: currentPresetId == id,
                    onSelected: (_) => _onPresetChanged(id),
                  )).toList(),
                ),
                ChoiceChip(
                  label: Text(_fakePresetNames[_symphonyId]!),
                  selected: currentPresetId == _symphonyId,
                  onSelected: (_) => _onFakePresetChanged(_symphonyId),
                ),
                ChoiceChip(
                  label: Text(_fakePresetNames[_hifiLiveId]!),
                  selected: currentPresetId == _hifiLiveId,
                  onSelected: (_) => _onFakePresetChanged(_hifiLiveId),
                ),
              ],
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Custom Presets', style: Theme.of(context).textTheme.titleLarge),
              ),
              if (customPresets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('Press the + button to create a preset.')),
                ),
              ...customPresets.map((preset) {
                final int id = preset['id'];
                final String name = preset['name'];
                return ListTile(
                  title: Text(name),
                  leading: Radio<int>(
                    value: id,
                    groupValue: currentPresetId,
                    onChanged: _onPresetChanged,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _navigateToEditor(preset: preset)), // Navigate to edit
                      IconButton(
                          icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                          onPressed: () => _showDeleteConfirmationDialog(preset) // <-- Pass the whole map here too
                      ),
                    ],
                  ),
                  onTap: () => _onPresetChanged(id),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}