// lib/settings_page.dart
import 'package:flutter/material.dart';
import 'main.dart';
import 'package:provider/provider.dart';
import 'services/theme_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          _buildThemeModeCard(context, themeService),
          const SizedBox(height: 16),
          _buildAccentColorCard(context, themeService),
        ],
      ),
    );
  }

  Widget _buildThemeModeCard(
      BuildContext context, ThemeService themeService) {
    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.brightness_6_rounded,
                  size: 28,
                  color: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.color
                      ?.withOpacity(0.8),
                ),
                const SizedBox(width: 12),
                Text('Appearance',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const Divider(height: 24),
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              value: ThemeMode.system,
              groupValue: themeService.themeMode,
              onChanged: (mode) => themeService.setThemeMode(mode!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: themeService.themeMode,
              onChanged: (mode) => themeService.setThemeMode(mode!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: themeService.themeMode,
              onChanged: (mode) => themeService.setThemeMode(mode!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccentColorCard(
      BuildContext context, ThemeService themeService) {
    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.color_lens_rounded,
                  size: 28,
                  color: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.color
                      ?.withOpacity(0.8),
                ),
                const SizedBox(width: 12),
                Text('Accent Color',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: ThemeService.availableColors.map((color) {
                final isSelected =
                    themeService.accentColor.value == color.value;
                return GestureDetector(
                  onTap: () => themeService.setAccentColor(color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3.0)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
} 