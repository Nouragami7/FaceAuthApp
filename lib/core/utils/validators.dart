import 'package:flutter/widgets.dart';

class Validators {
  static String? id(String? v) {
    if (v == null || v.trim().isEmpty) return 'ID is required';
    final id = int.tryParse(v.trim());
    if (id == null) return 'ID must be numeric';
    if (id <= 0) return 'ID must be positive';
    return null;
  }

  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    if (v.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static FormFieldValidator<String> nonEmpty({String message = 'Required'}) {
    return (v) => (v == null || v.trim().isEmpty) ? message : null;
  }
}