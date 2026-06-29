import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final score = PasswordValidator.getStrengthScore(password);
    final feedback = PasswordValidator.getStrengthFeedback(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 6.0,
            minHeight: 4,
            backgroundColor: Colors.grey.shade800,
            valueColor: AlwaysStoppedAnimation<Color>(_getColor(score)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          feedback,
          style: TextStyle(
            fontSize: 11,
            color: _getColor(score),
          ),
        ),
      ],
    );
  }

  Color _getColor(int score) {
    if (score <= 1) return Colors.red;
    if (score <= 3) return Colors.orange;
    if (score <= 4) return Colors.yellow;
    return Colors.green;
  }
}
