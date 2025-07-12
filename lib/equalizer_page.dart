// lib/equalizer_page.dart

import 'package:flutter/material.dart';
import 'services/freebuds_service.dart';
import 'dart:math';

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  Map<String, dynamic>? _eqInfo;
  bool _isLoading = true;

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
    setState(() => _eqInfo!['current_preset_id'] = newId);
    await FreeBudsService.setEqualizerPreset(newId);
  }

  Future<void> _showDeleteConfirmationDialog(int id, String name) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text("Are you sure you want to delete the '$name' preset?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await FreeBudsService.deleteCustomEq(id);
              await _loadEqInfo(showLoader: false);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEqEditDialog({Map<dynamic, dynamic>? preset}) async {
    final bool isCreating = preset == null;
    final id = isCreating ? Random().nextInt(100) + 10 : preset!['id']; // Simple ID generation
    final nameController = TextEditingController(text: isCreating ? '' : preset!['name']);
    final values = isCreating ? List.filled(10, 0) : List<int>.from(preset!['values']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCreating ? 'Create Custom Preset' : 'Edit Preset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Preset Name')),
              const SizedBox(height: 20),
              ...List.generate(10, (index) {
                return StatefulBuilder(
                    builder: (context, setSliderState) {
                      return Row(
                        children: [
                          Text('${(values[index] / 10).toStringAsFixed(1)} dB', style: const TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              min: -60, max: 60, divisions: 24,
                              value: values[index].toDouble(),
                              onChanged: (newValue) => setSliderState(() => values[index] = newValue.round()),
                            ),
                          ),
                        ],
                      );
                    }
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              Navigator.of(context).pop();
              await FreeBudsService.createOrUpdateCustomEq(id, nameController.text, values);
              await _loadEqInfo(showLoader: false);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
        onPressed: _showEqEditDialog,
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80), // Padding for FAB
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Built-in Presets', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: builtInIds.map((id) => ChoiceChip(
                    label: Text(_presetNames[id] ?? 'Preset $id'),
                    selected: currentPresetId == id,
                    onSelected: (_) => _onPresetChanged(id),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
        if (customPresets.isNotEmpty)
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text('Custom Presets', style: Theme.of(context).textTheme.titleLarge),
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
                        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEqEditDialog(preset: preset)),
                        IconButton(icon: Icon(Icons.delete_outline, color: Colors.red.shade400), onPressed: () => _showDeleteConfirmationDialog(id, name)),
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