import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DuressPinDialog extends StatefulWidget {
  const DuressPinDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const DuressPinDialog(),
    );
  }

  @override
  State<DuressPinDialog> createState() => _DuressPinDialogState();
}

class _DuressPinDialogState extends State<DuressPinDialog> {
  final TextEditingController _pinController = TextEditingController();

  void _submit() {
    if (_pinController.text == "9999") {
      // Duress PIN entered: Trigger Decoy / Emergency Alert
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anti-Coercion Alert: Decoy payment mode activated.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: AppTheme.solanaPurple),
          SizedBox(width: 8),
          Text('Enter Security PIN'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter your APTO PIN to authorize or activate safety mode.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              counterText: '',
              hintText: '••••',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.solanaGreen),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.solanaGreen),
          child: const Text('Authorize', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
