import 'package:flutter/material.dart';
class LabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const LabeledTextField({super.key, required this.label, required this.controller, this.keyboardType});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: controller, keyboardType: keyboardType, decoration: InputDecoration(labelText: label)),
  );
}