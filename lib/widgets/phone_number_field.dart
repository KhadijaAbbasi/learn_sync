import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/supported_country.dart';

/// A phone-number input with an inline country-code picker.
/// Currently supports Pakistan (+92) and Saudi Arabia (+966).
///
/// This is a brand-new widget — it does not touch or replace
/// CustomTextField, so nothing existing is affected.
class PhoneNumberField extends StatefulWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    required this.hintText,
    this.initialCountry = SupportedCountry.pakistan,
    this.onCountryChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final SupportedCountry initialCountry;
  final ValueChanged<SupportedCountry>? onCountryChanged;
  final String? Function(String?)? validator;

  /// Combines a country's dial code with the locally-typed digits
  /// into one E.164-style string, e.g. "+923001234567".
  static String fullNumber(SupportedCountry country, String localDigits) {
    return '${country.dialCode}${localDigits.trim()}';
  }

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  late SupportedCountry _country;

  @override
  void initState() {
    super.initState();
    _country = widget.initialCountry;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<SupportedCountry>(
              value: _country,
              items: SupportedCountry.values
                  .map(
                    (country) => DropdownMenuItem(
                      value: country,
                      child: Text('${country.flag} ${country.dialCode}'),
                    ),
                  )
                  .toList(),
              onChanged: (country) {
                if (country == null) return;
                setState(() => _country = country);
                widget.controller.clear();
                widget.onCountryChanged?.call(country);
              },
            ),
          ),
          Container(
            height: 24,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: theme.dividerColor,
          ),
          Expanded(
            child: TextFormField(
              controller: widget.controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_country.numberLength),
              ],
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              validator: widget.validator,
            ),
          ),
        ],
      ),
    );
  }
}
