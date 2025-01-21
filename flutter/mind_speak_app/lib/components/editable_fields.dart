import 'package:flutter/material.dart';

class EditableField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType inputType;
  final int? maxLines;

  const EditableField({
    required this.controller,
    required this.label,
    this.inputType = TextInputType.text,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: inputType,
      maxLines: maxLines,
    );
  }
}
