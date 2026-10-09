import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// حقل إدخال موحد
class NapexTextField extends StatelessWidget {
  const NapexTextField({
    required this.controller,
    required this.label,
    super.key,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
    );
  }
}
