// lib/eq_editor_page.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'services/freebuds_service.dart';

// Clean, elegant EQ curve painter with active-point indicator
class EqualizerCurvePainter extends CustomPainter {
  final List<double> values;
  final int? activeIndex;
  final Color curveColor;

  EqualizerCurvePainter({
    required this.values,
    this.activeIndex,
    this.curveColor = Colors.blue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = i * size.height / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) return;

    // Glow effect
    final glowPaint = Paint()
      ..color = curveColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    // Main line
    final linePaint = Paint()
      ..color = curveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    double getY(double value) => size.height - ((value + 6) / 12) * size.height;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      points.add(Offset(x, getY(values[i])));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final cx = (p1.dx + p2.dx) / 2;
      path.cubicTo(cx, p1.dy, cx, p2.dy, p2.dx, p2.dy);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    // Draw active point
    if (activeIndex != null && activeIndex! >= 0 && activeIndex! < points.length) {
      final activePoint = points[activeIndex!];
      final dotPaint = Paint()..color = curveColor;
      canvas.drawCircle(activePoint, 5.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Subtle glass card with minimal effects
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding,
    this.opacity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(opacity)
                : Colors.white.withOpacity(opacity * 2),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Clean, modern slider with proper dB formatting
class ModernSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String label;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  const ModernSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.label,
    required this.onStart,
    required this.onEnd,
  });

  @override
  State<ModernSlider> createState() => _ModernSliderState();
}

class _ModernSliderState extends State<ModernSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.02)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Format dB value properly
  String get _formattedValue {
    final val = widget.value;
    if (val == 0) return '0';
    return '${val > 0 ? '+' : ''}${val.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // dB Value Display
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                constraints: const BoxConstraints(minWidth: 40),
                decoration: BoxDecoration(
                  color: _isActive
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formattedValue,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                    color: _isActive ? Colors.blue : null,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Slider
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: Colors.blue,
                      inactiveTrackColor: Colors.grey.withOpacity(0.3),
                      thumbColor: Colors.white,
                      overlayColor: Colors.blue.withOpacity(0.1),
                    ),
                    child: Slider(
                      min: widget.min,
                      max: widget.max,
                      value: widget.value,
                      onChanged: widget.onChanged,
                      onChangeStart: (v) {
                        widget.onStart();
                        setState(() => _isActive = true);
                        _controller.forward();
                      },
                      onChangeEnd: (v) {
                        widget.onEnd();
                        setState(() => _isActive = false);
                        _controller.reverse();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Frequency Label
              Text(
                '${widget.label}Hz',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- MAIN WIDGET ---
class EqEditorPage extends StatefulWidget {
  final Map<dynamic, dynamic>? initialPreset;
  const EqEditorPage({super.key, this.initialPreset});

  @override
  State<EqEditorPage> createState() => _EqEditorPageState();
}

class _EqEditorPageState extends State<EqEditorPage> with SingleTickerProviderStateMixin {
  late bool _isCreating;
  late TextEditingController _nameController;
  late List<double> _values;
  late List<double> _originalValues;
  int? _activeSliderIndex;

  late AnimationController _pageController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final List<String> _hzLabels = [
    "32",
    "64",
    "125",
    "250",
    "500",
    "1k",
    "2k",
    "4k",
    "8k",
    "16k"
  ];

  @override
  void initState() {
    super.initState();
    _isCreating = widget.initialPreset == null;
    _nameController = TextEditingController(
        text: _isCreating ? '' : widget.initialPreset!['name']);

    // Fix value conversion - ensure we're working with proper dB values
    final initialData = _isCreating
        ? List.filled(10, 0.0)
        : (widget.initialPreset!['values'] as List)
        .map((e) => (e is int ? e : int.parse(e.toString())) / 10.0)
        .toList();

    _values = List.from(initialData);
    _originalValues = List.from(initialData);

    _pageController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
            CurvedAnimation(parent: _pageController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pageController, curve: Curves.easeOut));
    _pageController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _resetValues() {
    setState(() {
      _values = List.from(_originalValues);
      _nameController.text = _isCreating ? '' : widget.initialPreset!['name'];
      _activeSliderIndex = null;
    });
  }

  Future<void> _onSave() async {
    if (_nameController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Preset name cannot be empty.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    try {
      final id = _isCreating
          ? DateTime.now().millisecondsSinceEpoch % 1000 + 10
          : widget.initialPreset!['id'];

      // Convert back to integer values for storage
      final valuesToSend = _values.map((e) => (e * 10).round()).toList();

      await FreeBudsService.createOrUpdateCustomEq(
          id, _nameController.text.trim(), valuesToSend);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preset: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(_isCreating ? 'Create Preset' : 'Edit Preset'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // EQ Curve Visualization
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: GlassCard(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(24.0),
                        child: SizedBox(
                          height: 120,
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: EqualizerCurvePainter(
                              values: _values,
                              activeIndex: _activeSliderIndex,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Preset Name Field
                  _buildNameField(),
                  const SizedBox(height: 24),

                  // EQ Sliders - Fixed to scale properly
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 250,
                      maxHeight: 400,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: List.generate(_values.length, (index) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            child: ModernSlider(
                              value: _values[index],
                              min: -6.0,
                              max: 6.0,
                              label: _hzLabels[index],
                              onChanged: (newValue) {
                                setState(() {
                                  _values[index] = newValue;
                                });
                              },
                              onStart: () {
                                setState(() {
                                  _activeSliderIndex = index;
                                });
                              },
                              onEnd: () {
                                setState(() {
                                  _activeSliderIndex = null;
                                });
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNameField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 0.5),
      ),
      child: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Preset Name',
          prefixIcon: Icon(Icons.label_outline),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        TextButton.icon(
          onPressed: _resetValues,
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _onSave,
          icon: const Icon(Icons.save),
          label: const Text('Save Preset'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}