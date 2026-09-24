import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/animation/animated_pressable.dart';
import '../../../../core/animation/page_transitions.dart';
import '../../../wallet/services/wallet_adapter_service.dart';
import '../pages/tap_to_pay_screen.dart';

class SendAmountSheet extends StatefulWidget {
  const SendAmountSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const SendAmountSheet(),
      ),
    );
  }

  @override
  State<SendAmountSheet> createState() => _SendAmountSheetState();
}

class _SendAmountSheetState extends State<SendAmountSheet> {
  String _amount = "0";
  String _currency = "USDC";

  final Map<String, String> _subText = const {
    '1': '',
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '.': '',
    '0': '+',
  };

  void _onKeyPress(String value) {
    setState(() {
      if (value == '.') {
        if (!_amount.contains('.')) {
          _amount += '.';
        }
      } else if (_amount == "0") {
        _amount = value;
      } else {
        _amount += value;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amount.length > 1) {
        _amount = _amount.substring(0, _amount.length - 1);
      } else {
        _amount = "0";
      }
    });
  }

  void _proceedToTap() {
    final parsed = double.tryParse(_amount) ?? 0.0;
    if (parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please enter a valid payment amount > 0'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    Navigator.of(context).pop(); // Close sheet
    Navigator.of(context).push(
      SlideFadeRouteBuilder(
        page: TapToPayScreen(
          amountUsdc: '$_amount $_currency',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppTheme.outlineBorder, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.all(24.0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Enter Send Amount',
                  style: AppTheme.serifHeading(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Amount Display Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: WalletAdapterService.instance.solBalanceNotifier,
                    builder: (context, solBal, child) {
                      return Text(
                        'Available: ${solBal.toStringAsFixed(2)} SOL',
                        style: AppTheme.sansBody(fontSize: 12, color: AppTheme.textSecondary),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _amount,
                          style: AppTheme.serifHeading(fontSize: 42, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currency = _currency == "USDC" ? "SOL" : "USDC";
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.seedVaultTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.seedVaultTeal, width: 1.0),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _currency,
                                  style: AppTheme.sansBody(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.seedVaultTeal,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.swap_vert_rounded, color: AppTheme.seedVaultTeal, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Numeric Dial Pad
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 1.25,
                crossAxisSpacing: 14,
                mainAxisSpacing: 10,
                children: [
                  ...['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0'].map(
                    (val) => _buildDialButton(
                      value: val,
                      subtext: _subText[val] ?? '',
                      onTap: () => _onKeyPress(val),
                    ),
                  ),
                  _buildDialButton(
                    icon: Icons.backspace_outlined,
                    onTap: _onBackspace,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Proceed to Tap Button
            SizedBox(
              width: double.infinity,
              child: AnimatedPressable(
                onTap: _proceedToTap,
                child: ElevatedButton.icon(
                  onPressed: null, // Gesture handled by AnimatedPressable
                  icon: const Icon(Icons.nfc_rounded, color: AppTheme.textPrimary, size: 20),
                  label: Text(
                    'Proceed to Tap to Pay ($_amount $_currency)',
                    style: AppTheme.sansBody(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.seedVaultTeal,
                    disabledBackgroundColor: AppTheme.seedVaultTeal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDialButton({
    String? value,
    String subtext = '',
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return AnimatedPressable(
      onTap: onTap,
      scaleFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.cardBg,
          border: Border.all(color: AppTheme.outlineBorder, width: 1.2),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: AppTheme.textSecondary, size: 20)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value!,
                      style: AppTheme.sansBody(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (subtext.isNotEmpty) ...[
                      Text(
                        subtext,
                        style: AppTheme.sansBody(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
