import 'package:flutter/material.dart';

class StepperField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final double step;
  final double? min;
  final double? max;
  final int precision; // number of decimal places
  final TextInputType keyboardType;
  final VoidCallback? onChanged;
  final String? suffixText; // optional unit text in the field (e.g., kts, °C)
  final Color? fillColor; // optional background tint

  const StepperField({
    super.key,
    required this.label,
    required this.controller,
    required this.step,
    this.min,
    this.max,
    this.precision = 0,
    this.keyboardType = TextInputType.number,
    this.onChanged,
    this.suffixText,
    this.fillColor,
  });

  double _parse() {
    final t = controller.text.trim();
    final v = double.tryParse(t);
    return v ?? 0.0;
  }

  void _set(double v) {
    if (min != null && v < min!) v = min!;
    if (max != null && v > max!) v = max!;
    final formatted = precision > 0 ? v.toStringAsFixed(precision) : v.toStringAsFixed(0);
    controller.text = formatted;
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    if (onChanged != null) onChanged!();
  }

  @override
  Widget build(BuildContext context) {
    // Build a TextField with two small +/- buttons in the suffix
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: fillColor != null,
        fillColor: fillColor,
        suffixIcon: SizedBox(
          width: 96,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Decrease',
                icon: const Icon(Icons.remove),
                onPressed: () {
                  final v = _parse() - step;
                  _set(v);
                },
              ),
              IconButton(
                tooltip: 'Increase',
                icon: const Icon(Icons.add),
                onPressed: () {
                  final v = _parse() + step;
                  _set(v);
                },
              ),
            ],
          ),
        ),
      ),
      onChanged: (_) => onChanged?.call(),
    );
  }
}
