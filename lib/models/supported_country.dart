/// Countries supported for phone-based login/signup.
/// Add more entries here later if more countries are needed.
enum SupportedCountry {
  pakistan(name: 'Pakistan', dialCode: '+92', flag: '🇵🇰', numberLength: 10),
  saudiArabia(name: 'Saudi Arabia', dialCode: '+966', flag: '🇸🇦', numberLength: 9);

  const SupportedCountry({
    required this.name,
    required this.dialCode,
    required this.flag,
    required this.numberLength,
  });

  final String name;
  final String dialCode;
  final String flag;

  /// Expected number of local digits after the dial code
  /// (e.g. Pakistan mobile numbers: 3XXXXXXXXX -> 10 digits).
  final int numberLength;
}
