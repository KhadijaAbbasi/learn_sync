import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class CustomDropdownField<T> extends StatelessWidget {
  const CustomDropdownField({
    super.key,
    required this.value,
    required this.hintText,
    required this.prefixIcon,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  final T? value;
  final String hintText;
  final IconData prefixIcon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final muted = AppColors.textSecondary(brightness);
    final textStyle = TextStyle(
      color: AppColors.textPrimary(brightness),
      fontSize: 14.5,
      height: 1.35,
    );

    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(
        prefixIcon: Icon(prefixIcon),
        // Match CustomTextField / theme field height (no extra InputDecorator stack).
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      hint: Text(
        hintText,
        style: textStyle.copyWith(color: muted),
      ),
      style: textStyle,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: muted),
      dropdownColor: AppColors.fieldFill(brightness),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }
}
