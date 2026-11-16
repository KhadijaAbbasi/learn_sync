import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.obscureText = false,
    this.autofillHints,
    this.onFieldSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    this.capitalizeWords = false,
    this.maxLength,
    this.inputFormatters,
    this.errorText,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final int maxLines;
  final int? minLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;
  final bool capitalizeWords;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final multiline = !widget.obscureText && widget.maxLines > 1;

    return TextFormField(
      controller: widget.controller,
      keyboardType: multiline ? TextInputType.multiline : widget.keyboardType,
      textInputAction: multiline
          ? TextInputAction.newline
          : widget.textInputAction,
      textCapitalization: widget.capitalizeWords
          ? TextCapitalization.words
          : TextCapitalization.none,
      validator: widget.validator,
      obscureText: _obscured,
      autocorrect: !widget.obscureText,
      enableSuggestions: !widget.obscureText,
      spellCheckConfiguration: widget.obscureText
          ? const SpellCheckConfiguration.disabled()
          : null,
      enabled: widget.enabled,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onFieldSubmitted,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      style: TextStyle(
        color: AppColors.textPrimary(brightness),
        fontSize: 14.5,
        height: 1.35,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon:
            widget.suffix ??
            (widget.obscureText
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  )
                : null),
        counterText: widget.maxLength == null ? null : '',
        errorText: widget.errorText,
      ),
    );
  }
}
