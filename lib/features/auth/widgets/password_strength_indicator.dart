import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../core/services/auth_service.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final void Function(PasswordStrength)? onStrengthChanged;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.onStrengthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final strength = _getPasswordStrength(password);
    final requirements = _getRequirements(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength Bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Password Strength',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  strength.name.toUpperCase(),
                  style: TextStyle(
                    color: _getStrengthColor(strength),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _getStrengthValue(strength),
                minHeight: 8,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(_getStrengthColor(strength)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Requirements Checklist
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Requirements',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildRequirementsList(requirements),
          ],
        ),
      ],
    );
  }

  PasswordStrength _getPasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.empty;

    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasNumbers = password.contains(RegExp(r'\d'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:,.<>?]'));

    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (hasLower) strength++;
    if (hasUpper) strength++;
    if (hasNumbers) strength++;
    if (hasSpecial) strength++;

    if (strength <= 2) return PasswordStrength.weak;
    if (strength <= 4) return PasswordStrength.fair;
    if (strength <= 5) return PasswordStrength.good;
    return PasswordStrength.strong;
  }

  Map<String, bool> _getRequirements(String password) {
    return {
      'At least 12 characters': password.length >= 12,
      'Uppercase letter (A-Z)': password.contains(RegExp(r'[A-Z]')),
      'Lowercase letter (a-z)': password.contains(RegExp(r'[a-z]')),
      'Number (0-9)': password.contains(RegExp(r'\d')),
      'Special character (!@#\$%^&*)': password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:,.<>?]')),
    };
  }

  List<Widget> _buildRequirementsList(Map<String, bool> requirements) {
    return requirements.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(
              entry.value ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: entry.value ? AppColors.success : AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              entry.key,
              style: TextStyle(
                color: entry.value ? AppColors.textSecondary : AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  double _getStrengthValue(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.empty:
        return 0;
      case PasswordStrength.weak:
        return 0.25;
      case PasswordStrength.fair:
        return 0.5;
      case PasswordStrength.good:
        return 0.75;
      case PasswordStrength.strong:
        return 1.0;
    }
  }

  Color _getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.empty:
        return AppColors.textTertiary;
      case PasswordStrength.weak:
        return AppColors.error;
      case PasswordStrength.fair:
        return AppColors.warning;
      case PasswordStrength.good:
        return Color(0xFFFCD34D);
      case PasswordStrength.strong:
        return AppColors.success;
    }
  }
}

enum PasswordStrength {
  empty,
  weak,
  fair,
  good,
  strong,
}
