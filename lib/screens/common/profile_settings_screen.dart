import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/constants/app_routes.dart';
import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../services/profile_photo.dart';
import '../../widgets/dashboard_scaffold.dart';
import '../../widgets/user_avatar.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({
    super.key,
    this.viewUserId,
    this.fallbackUser,
    this.readOnly = false,
    this.embeddedInShell = false,
    this.initialEditing = false,
  });

  /// When set (e.g. teacher viewing a student), load this profile instead of
  /// the signed-in user and force a read-only experience.
  final String? viewUserId;
  final UserModel? fallbackUser;
  final bool readOnly;

  /// When true (bottom-nav Profile tab), hide back and show Settings.
  final bool embeddedInShell;

  /// Open directly in edit mode (e.g. from Settings → Edit profile).
  final bool initialEditing;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  final _officeTiming = TextEditingController();
  final _officeNumber = TextEditingController();
  final _country = TextEditingController();
  final _department = TextEditingController();
  final _university = TextEditingController();
  final _enrollmentYear = TextEditingController();
  String _gender = 'female';
  String _photoUrl = '';
  late bool _editing;
  var _saving = false;
  var _uploadingPhoto = false;
  String? _photoError;
  UserModel? _viewedUser;
  var _loadingViewed = false;

  bool get _isReadOnlyView =>
      widget.readOnly || (widget.viewUserId?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _editing = widget.initialEditing && !widget.readOnly;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_isReadOnlyView) {
      await _loadViewedUser();
    } else {
      _hydrate(AppScope.of(context).sessionController.user);
    }
  }

  Future<void> _loadViewedUser() async {
    final id =
        widget.viewUserId?.trim() ?? widget.fallbackUser?.id.trim() ?? '';
    setState(() => _loadingViewed = true);
    UserModel? loaded;
    if (id.isNotEmpty) {
      try {
        loaded = await AppScope.of(context).authService.fetchUserById(id);
      } catch (_) {
        loaded = null;
      }
    }
    if (!mounted) {
      return;
    }
    final user = loaded ?? widget.fallbackUser;
    setState(() {
      _viewedUser = user;
      _loadingViewed = false;
      _editing = false;
    });
    _hydrate(user);
  }

  void _hydrate(UserModel? user) {
    if (user == null) {
      return;
    }
    setState(() {
      _phone.text = user.phone;
      _bio.text = user.bio;
      _officeTiming.text = user.officeTiming;
      _officeNumber.text = user.officeNumber;
      _gender = user.gender.isEmpty ? 'female' : user.gender;
      _country.text = user.country;
      _department.text = user.department;
      _university.text = user.university;
      _enrollmentYear.text = user.enrollmentYear;
      _photoUrl = user.photoUrl;
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _bio.dispose();
    _officeTiming.dispose();
    _officeNumber.dispose();
    _country.dispose();
    _department.dispose();
    _university.dispose();
    _enrollmentYear.dispose();
    super.dispose();
  }

  String _display(String value, AppLocalizations l10n) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? l10n.notSet : trimmed;
  }

  String _genderLabel(AppLocalizations l10n, String value) {
    return switch (value.toLowerCase()) {
      'male' => l10n.genderMale,
      'female' => l10n.genderFemale,
      'other' => l10n.genderOther,
      _ => _display(value, l10n),
    };
  }

  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    if (user == null || _uploadingPhoto) {
      return;
    }
    setState(() {
      _photoError = null;
      _uploadingPhoto = true;
    });
    try {
      final picked = await ProfilePhoto.pick();
      if (picked == null || !mounted) {
        return;
      }
      final url = await scope.authService.saveAvatar(
        userId: user.id,
        bytes: picked.bytes,
        fileName: picked.name,
      );
      final updated = user.copyWith(photoUrl: url);
      await scope.authService.updateProfile(updated);
      if (!mounted) {
        return;
      }
      scope.sessionController.updateUser(updated);
      setState(() => _photoUrl = url);
    } on ProfilePhotoException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _photoError = error.code == 'too_large'
            ? l10n.profilePhotoTooLarge
            : l10n.profilePhotoInvalidType;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _photoError = l10n.profileSaveFailed);
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _pickOfficeTiming() async {
    final now = TimeOfDay.now();
    final start = await showTimePicker(
      context: context,
      initialTime: now,
      helpText: AppLocalizations.of(context).officeTiming,
    );
    if (!mounted || start == null) {
      return;
    }

    final startMinutes = start.hour * 60 + start.minute;
    final suggestedEnd = TimeOfDay(
      hour: ((startMinutes + 60) ~/ 60) % 24,
      minute: (startMinutes + 60) % 60,
    );
    final end = await showTimePicker(
      context: context,
      initialTime: suggestedEnd,
      helpText: AppLocalizations.of(context).officeTiming,
    );
    if (!mounted || end == null) {
      return;
    }

    final localizations = MaterialLocalizations.of(context);
    setState(() {
      _officeTiming.text =
          '${localizations.formatTimeOfDay(start)} – '
          '${localizations.formatTimeOfDay(end)}';
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final user = AppScope.of(context).sessionController.user;
    if (user == null || _saving) {
      return;
    }
    setState(() => _saving = true);
    final updated = user.copyWith(
      photoUrl: _photoUrl,
      phone: _phone.text.trim(),
      gender: _gender,
      bio: _bio.text.trim(),
      officeTiming: _officeTiming.text.trim(),
      officeNumber: _officeNumber.text.trim(),
      country: _country.text.trim(),
      department: _department.text.trim(),
      university: _university.text.trim(),
      enrollmentYear: _enrollmentYear.text.trim(),
    );
    try {
      final saved = await AppScope.of(context).authService.updateProfile(updated);
      if (!mounted) {
        return;
      }
      AppScope.of(context).sessionController.updateUser(saved);
      setState(() => _editing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileSaveFailed)));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final sessionUser = scope.sessionController.user;
    final user = _isReadOnlyView ? _viewedUser : sessionUser;
    final brightness = Theme.of(context).brightness;
    final name = user?.fullName ?? l10n.appName;
    final isTeacherRole = user?.role == UserRole.teacher;
    final role = isTeacherRole ? l10n.teacher : l10n.student;
    final readOnly = _isReadOnlyView;
    final title = _isReadOnlyView && !isTeacherRole
        ? l10n.studentProfileTitle
        : l10n.navProfile;

    if (_loadingViewed) {
      return DashboardScaffold(
        embeddedInShell: widget.embeddedInShell,
        roleLabel: title,
        appBarTitle: title,
        appBarBackButton: !widget.embeddedInShell,
        appBarCenterTitle: true,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DashboardScaffold(
      embeddedInShell: widget.embeddedInShell,
      roleLabel: title,
      appBarTitle: title,
      appBarBackButton: !widget.embeddedInShell,
      appBarCenterTitle: true,
      appBarActions: [
        if (widget.embeddedInShell)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: IconButton(
              tooltip: l10n.navSettings,
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.settings);
              },
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileHeroCard(
            name: name,
            role: role,
            photoUrl: _photoUrl,
            uploadingPhoto: _uploadingPhoto,
            editable: !readOnly && _editing,
            onPhotoTap: readOnly ? null : _pickPhoto,
            phone: _display(_phone.text, l10n),
            gender: _genderLabel(l10n, _gender),
            country: _display(_country.text, l10n),
            email: _display(user?.email ?? '', l10n),
            editing: _editing && !readOnly,
            phoneController: _phone,
            countryController: _country,
            genderValue: _gender,
            onGenderChanged: (value) {
              if (value == null) return;
              setState(() => _gender = value);
            },
            l10n: l10n,
            brightness: brightness,
          ),
          if (_photoError != null) ...[
            const SizedBox(height: 10),
            Text(
              _photoError!,
              style: const TextStyle(color: AppColors.coral, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          if (isTeacherRole)
            _InfoSectionCard(
              icon: Icons.apartment_rounded,
              title: l10n.officeInformation,
              brightness: brightness,
              rows: [
                _InfoRowData(
                  icon: Icons.meeting_room_outlined,
                  label: l10n.officeNumber,
                  value: _display(_officeNumber.text, l10n),
                  controller: _officeNumber,
                ),
                _InfoRowData(
                  icon: Icons.schedule_rounded,
                  label: l10n.officeTiming,
                  value: _display(_officeTiming.text, l10n),
                  controller: _officeTiming,
                  onTap: _editing && !readOnly ? _pickOfficeTiming : null,
                ),
                _InfoRowData(
                  icon: Icons.menu_book_rounded,
                  label: l10n.department,
                  value: _display(_department.text, l10n),
                  controller: _department,
                ),
              ],
              editing: _editing && !readOnly,
            )
          else
            _InfoSectionCard(
              icon: Icons.school_rounded,
              title: l10n.academicInformation,
              brightness: brightness,
              rows: [
                _InfoRowData(
                  icon: Icons.menu_book_rounded,
                  label: l10n.department,
                  value: _display(_department.text, l10n),
                  controller: _department,
                ),
                _InfoRowData(
                  icon: Icons.account_balance_rounded,
                  label: l10n.university,
                  value: _display(_university.text, l10n),
                  controller: _university,
                ),
                _InfoRowData(
                  icon: Icons.calendar_month_rounded,
                  label: l10n.enrollmentYear,
                  value: _display(_enrollmentYear.text, l10n),
                  controller: _enrollmentYear,
                  keyboardType: TextInputType.number,
                ),
              ],
              editing: _editing && !readOnly,
            ),
          const SizedBox(height: 14),
          _AboutCard(
            brightness: brightness,
            title: l10n.aboutMe,
            editing: _editing && !readOnly,
            controller: _bio,
            readValue: _display(_bio.text, l10n),
            hint: l10n.bioHint,
          ),
          if (!readOnly && _editing) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.saveChanges),
              ),
            ),
          ],
          SizedBox(height: AppResponsive.pagePadding(context)),
        ],
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.name,
    required this.role,
    required this.photoUrl,
    required this.uploadingPhoto,
    required this.editable,
    required this.phone,
    required this.gender,
    required this.country,
    required this.email,
    required this.editing,
    required this.phoneController,
    required this.countryController,
    required this.genderValue,
    required this.onGenderChanged,
    required this.l10n,
    required this.brightness,
    this.onPhotoTap,
  });

  final String name;
  final String role;
  final String photoUrl;
  final bool uploadingPhoto;
  final bool editable;
  final VoidCallback? onPhotoTap;
  final String phone;
  final String gender;
  final String country;
  final String email;
  final bool editing;
  final TextEditingController phoneController;
  final TextEditingController countryController;
  final String genderValue;
  final ValueChanged<String?> onGenderChanged;
  final AppLocalizations l10n;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      brightness: brightness,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _EditableAvatar(
                name: name,
                photoUrl: photoUrl,
                uploading: uploadingPhoto,
                editable: editable,
                onTap: onPhotoTap,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: AppColors.textPrimary(brightness),
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.teal, width: 1.3),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: AppColors.border(brightness)),
          const SizedBox(height: 12),
          if (editing)
            Column(
              children: [
                _EditField(
                  label: l10n.phoneShort,
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _GenderDropdown(
                  label: l10n.gender,
                  value: genderValue,
                  onChanged: onGenderChanged,
                  l10n: l10n,
                ),
                const SizedBox(height: 10),
                _EditField(
                  label: l10n.country,
                  controller: countryController,
                ),
                const SizedBox(height: 10),
                _ReadOnlyField(label: l10n.emailLabel, value: email),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _QuickStat(
                    icon: Icons.phone_rounded,
                    label: l10n.phoneShort,
                    value: phone,
                  ),
                ),
                _VDivider(brightness: brightness),
                Expanded(
                  child: _QuickStat(
                    icon: Icons.wc_rounded,
                    label: l10n.gender,
                    value: gender,
                  ),
                ),
                _VDivider(brightness: brightness),
                Expanded(
                  child: _QuickStat(
                    icon: Icons.location_on_rounded,
                    label: l10n.country,
                    value: country,
                  ),
                ),
              ],
            ),
          if (!editing) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.border(brightness)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.email_rounded, color: AppColors.teal, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.emailLabel,
                        style: TextStyle(
                          color: AppColors.textSecondary(brightness),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          color: AppColors.textPrimary(brightness),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoSectionCard extends StatelessWidget {
  const _InfoSectionCard({
    required this.icon,
    required this.title,
    required this.rows,
    required this.editing,
    required this.brightness,
  });

  final IconData icon;
  final String title;
  final List<_InfoRowData> rows;
  final bool editing;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      brightness: brightness,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.teal, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary(brightness),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < rows.length; i++) ...[
            if (editing)
              Padding(
                padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 10),
                child: rows[i].onTap != null
                    ? _EditField(
                        label: rows[i].label,
                        controller: rows[i].controller!,
                        readOnly: true,
                        onTap: rows[i].onTap,
                        suffix: const Icon(Icons.schedule_rounded),
                      )
                    : _EditField(
                        label: rows[i].label,
                        controller: rows[i].controller!,
                        keyboardType: rows[i].keyboardType,
                      ),
              )
            else ...[
              _DetailRow(
                icon: rows[i].icon,
                label: rows[i].label,
                value: rows[i].value,
              ),
              if (i != rows.length - 1)
                Divider(height: 22, color: AppColors.border(brightness)),
            ],
          ],
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.brightness,
    required this.title,
    required this.editing,
    required this.controller,
    required this.readValue,
    required this.hint,
  });

  final Brightness brightness;
  final String title;
  final bool editing;
  final TextEditingController controller;
  final String readValue;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      brightness: brightness,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_rounded, color: AppColors.teal, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary(brightness),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (editing)
            TextField(
              controller: controller,
              maxLines: 4,
              style: TextStyle(
                color: AppColors.textPrimary(brightness),
                height: 1.4,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                fillColor: brightness == Brightness.dark
                    ? AppColors.darkBackground
                    : const Color(0xFFF4F7FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.border(brightness)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.border(brightness)),
                ),
              ),
            )
          else
            Text(
              readValue,
              style: TextStyle(
                color: AppColors.textSecondary(brightness),
                height: 1.45,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
    this.controller,
    this.onTap,
    this.keyboardType,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.brightness, required this.child});

  final Brightness brightness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: brightness == Brightness.dark ? AppColors.darkSurface : Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border(brightness)),
        ),
        child: child,
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.teal, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary(brightness),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimary(brightness),
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.border(brightness),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.teal, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary(brightness),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textPrimary(brightness),
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffix,
        filled: true,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        fillColor: brightness == Brightness.dark
            ? AppColors.darkBackground
            : const Color(0xFFF4F7FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: brightness == Brightness.dark
            ? AppColors.darkBackground
            : const Color(0xFFF4F7FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
      ),
      child: Text(
        value,
        style: TextStyle(color: AppColors.textPrimary(brightness)),
      ),
    );
  }
}

class _GenderDropdown extends StatelessWidget {
  const _GenderDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.l10n,
  });

  final String label;
  final String value;
  final ValueChanged<String?> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final normalized = switch (value.toLowerCase()) {
      'male' || 'female' || 'other' => value.toLowerCase(),
      _ => 'female',
    };
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: brightness == Brightness.dark
            ? AppColors.darkBackground
            : const Color(0xFFF4F7FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: normalized,
          isExpanded: true,
          items: [
            DropdownMenuItem(value: 'female', child: Text(l10n.genderFemale)),
            DropdownMenuItem(value: 'male', child: Text(l10n.genderMale)),
            DropdownMenuItem(value: 'other', child: Text(l10n.genderOther)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.name,
    required this.photoUrl,
    required this.uploading,
    required this.editable,
    this.onTap,
  });

  final String name;
  final String photoUrl;
  final bool uploading;
  final bool editable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.teal.withValues(alpha: 0.35)),
          ),
          child: UserAvatar(name: name, photoUrl: photoUrl, radius: 42),
        ),
        if (editable)
          PositionedDirectional(
            end: -2,
            bottom: 2,
            child: Material(
              color: AppColors.teal,
              elevation: 3,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: uploading ? null : onTap,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
