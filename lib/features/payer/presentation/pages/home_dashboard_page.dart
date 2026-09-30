import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/animation/animated_pressable.dart';
import '../../../../core/animation/staggered_entrance.dart';
import '../../../../core/animation/fast_rolling_counter_text.dart';
import '../../../../core/animation/shimmer_loading.dart';
import '../../../wallet/domain/models/wallet_provider.dart';
import '../../../wallet/domain/models/wallet_transaction.dart';
import '../../../wallet/domain/models/wallet_transaction_details.dart';
import '../../../wallet/services/wallet_adapter_service.dart';
import '../../../wallet/services/financial_insights_service.dart';
import '../widgets/financial_insights_card.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031016),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/assets/images/Aptowallet.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF031016),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppTheme.seedVaultTeal,
              backgroundColor: AppTheme.cardBg,
              onRefresh: () async {
                await Future.wait([
                  WalletAdapterService.instance.refreshBalance(),
                  FinancialInsightsService.instance.loadInsights(),
                ]);
                if (mounted) {
                  setState(() {});
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 16.0,
                  bottom: MediaQuery.of(context).padding.bottom + 100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Title
                    StaggeredEntrance(
                      index: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'lib/assets/images/logo.jpg',
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'APTO',
                                style: AppTheme.serifHeading(
                                    fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: 'Wallet settings',
                            onPressed: () => _showWalletSettings(context),
                            icon: const Icon(Icons.settings_outlined),
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Hero Section: Disconnected Prompt vs Connected Balance Card
                    StaggeredEntrance(
                      index: 1,
                      child: ValueListenableBuilder<bool>(
                        valueListenable:
                            WalletAdapterService.instance.isConnectedNotifier,
                        builder: (context, isConnected, child) {
                          if (!isConnected) {
                            return _buildDisconnectedWalletCard(context);
                          }
                          return _buildConnectedBalanceCard(context);
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Financial Flow Insights Card (Received, Spent, Network Fees with Circular Distribution)
                    const StaggeredEntrance(
                      index: 2,
                      child: FinancialInsightsCard(),
                    ),

                    const SizedBox(height: 32),

                    // Recent Activity Header
                    StaggeredEntrance(
                      index: 3,
                      child: Text(
                        'Recent activity',
                        style: AppTheme.sansBody(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return FutureBuilder<List<WalletTransaction>>(
      future: WalletAdapterService.instance.fetchRecentTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: LoadingAnimationWidget.twistingDots(
              leftDotColor: AppTheme.seedVaultTeal,
              rightDotColor: const Color(0xFFD6E2E4),
              size: 34,
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Unable to load transactions',
            style:
                AppTheme.sansBody(fontSize: 13, color: AppTheme.textSecondary),
          );
        }

        final transactions = snapshot.data ?? const [];
        if (transactions.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.outlineBorder,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FA8B7).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF4FA8B7),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No transactions yet',
                  style: AppTheme.serifHeading(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your tap-to-pay and transfer activity will appear here once verified on Solana.',
                  textAlign: TextAlign.center,
                  style: AppTheme.sansBody(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return _ShowMoreActivityList(
          transactions: transactions,
          onShowDetails: (sig) => _showTransactionDetails(context, sig),
          subtitleBuilder: _transactionSubtitle,
        );
      },
    );
  }

  String _transactionSubtitle(WalletTransaction transaction) {
    final counterparty = transaction.shortCounterparty;
    String prefix = '';
    if (counterparty.isNotEmpty) {
      prefix =
          transaction.isSent ? 'To $counterparty • ' : 'From $counterparty • ';
    } else {
      final sig = transaction.signature;
      final shortSig = sig.length > 8
          ? '${sig.substring(0, 4)}...${sig.substring(sig.length - 4)}'
          : sig;
      prefix = '$shortSig • ';
    }

    if (transaction.blockTime == null) {
      return prefix.replaceAll(' • ', '');
    }

    final date = DateTime.fromMillisecondsSinceEpoch(
      transaction.blockTime! * 1000,
    );
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');

    return '$prefix${date.month}/${date.day}/${date.year} $hour:$minute $ampm';
  }

  void _showTransactionDetails(BuildContext context, String signature) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FutureBuilder<WalletTransactionDetails?>(
          future:
              WalletAdapterService.instance.fetchTransactionDetails(signature),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final details = snapshot.data;
            if (snapshot.hasError || details == null) {
              return const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Transaction details unavailable'),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transaction details',
                        style: AppTheme.serifHeading(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _detailRow('Status',
                        details.isSuccessful ? 'Confirmed' : 'Failed'),
                    _detailRow('Signature', _shortSignature(details.signature)),
                    _detailRow('Slot', details.slot.toString()),
                    _detailRow(
                        'Fee',
                        details.feeLamports == null
                            ? 'Unavailable'
                            : '${details.feeLamports} lamports'),
                    if (details.blockTime != null)
                      _detailRow('Date', _formatDate(details.blockTime!)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTheme.sansBody(
                  fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(width: 20),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: AppTheme.sansBody(
                    fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  String _shortSignature(String signature) {
    if (signature.length <= 12) return signature;
    return '${signature.substring(0, 6)}...${signature.substring(signature.length - 6)}';
  }

  String _formatDate(int blockTime) {
    final date = DateTime.fromMillisecondsSinceEpoch(blockTime * 1000);
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _buildDisconnectedWalletCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppTheme.seedVaultTeal.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.seedVaultTeal.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'lib/assets/images/logo.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Connect Solana Wallet',
              style: AppTheme.serifHeading(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: AnimatedPressable(
              onTap: () async {
                await WalletAdapterService.instance
                    .selectWallet(WalletProvider.seedVault);
              },
              child: ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.link_rounded,
                    color: AppTheme.textPrimary, size: 18),
                label: Text('Connect Wallet',
                    style: AppTheme.sansBody(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.seedVaultTeal,
                  disabledBackgroundColor: AppTheme.seedVaultTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedBalanceCard(BuildContext context) {
    return AnimatedPressable(
      onTap: () => _showWalletSettings(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ValueListenableBuilder<WalletProvider>(
                  valueListenable:
                      WalletAdapterService.instance.activeWalletNotifier,
                  builder: (context, activeWallet, child) {
                    return ValueListenableBuilder<String>(
                      valueListenable:
                          WalletAdapterService.instance.walletAddressNotifier,
                      builder: (context, addressStr, child) {
                        return Row(
                          children: [
                            Icon(activeWallet.icon,
                                color: activeWallet.color, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${activeWallet.name} ($addressStr)',
                              style: AppTheme.sansBody(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                final fullAddress = WalletAdapterService
                                    .instance.fullAddressNotifier.value;
                                if (fullAddress.isNotEmpty) {
                                  Clipboard.setData(
                                      ClipboardData(text: fullAddress));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Wallet address copied to clipboard',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: AppTheme.cardBg,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: AppTheme.seedVaultTeal
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.copy_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable:
                  WalletAdapterService.instance.isBalanceLoadingNotifier,
              builder: (context, isLoading, child) {
                return ValueListenableBuilder<double>(
                  valueListenable:
                      WalletAdapterService.instance.solBalanceNotifier,
                  builder: (context, solBal, child) {
                    if (solBal == 0.0 && isLoading) {
                      return const ShimmerLoading(
                        isLoading: true,
                        baseColor: Color(0xFF0C242B),
                        highlightColor: Color(0xFF286472),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            ShimmerBox(width: 140, height: 36, borderRadius: 8),
                            SizedBox(width: 8),
                            ShimmerBox(width: 44, height: 18, borderRadius: 6),
                            SizedBox(width: 12),
                            ShimmerBox(width: 75, height: 16, borderRadius: 6),
                          ],
                        ),
                      );
                    }

                    final balanceRow = FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          FastRollingCounterText(
                            targetValue: solBal,
                            decimals: 3,
                            style: AppTheme.serifHeading(
                                fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SOL',
                            style: AppTheme.sansBody(
                                fontSize: 16, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 12),
                          ValueListenableBuilder<double>(
                            valueListenable: WalletAdapterService
                                .instance.usdcBalanceNotifier,
                            builder: (context, usdcBal, child) {
                              return FastRollingCounterText(
                                targetValue: usdcBal,
                                decimals: 2,
                                prefix: '(',
                                suffix: 'USDC)',
                                style: AppTheme.sansBody(
                                    fontSize: 13,
                                    color: AppTheme.seedVaultTeal),
                              );
                            },
                          ),
                        ],
                      ),
                    );

                    if (isLoading) {
                      return ShimmerLoading(
                        isLoading: true,
                        baseColor: Colors.white,
                        highlightColor: AppTheme.seedVaultTeal,
                        child: balanceRow,
                      );
                    }

                    return balanceRow;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showWalletSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.background,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'lib/assets/images/logo.jpg',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'APTO',
                          style: AppTheme.serifHeading(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Solana NFC Tap-to-Pay',
                          style: AppTheme.sansBody(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.outlineBorder),
              ListTile(
                leading:
                    const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Disconnect',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDisconnect(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDisconnect(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Disconnect Wallet',
                style: AppTheme.serifHeading(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to disconnect your active Solana wallet from APTO?',
            style: AppTheme.sansBody(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: AppTheme.sansBody(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Disconnect',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      WalletAdapterService.instance.disconnect();
    }
  }
}

class _ShowMoreActivityList extends StatefulWidget {
  final List<WalletTransaction> transactions;
  final void Function(String signature) onShowDetails;
  final String Function(WalletTransaction) subtitleBuilder;

  const _ShowMoreActivityList({
    required this.transactions,
    required this.onShowDetails,
    required this.subtitleBuilder,
  });

  @override
  State<_ShowMoreActivityList> createState() => _ShowMoreActivityListState();
}

class _ShowMoreActivityListState extends State<_ShowMoreActivityList> {
  bool _showAll = false;
  static const int _initialCount = 5;

  @override
  Widget build(BuildContext context) {
    final transactions = widget.transactions;
    final hasMore = transactions.length > _initialCount;
    final visibleCount = _showAll
        ? transactions.length
        : transactions.length.clamp(0, _initialCount);

    return Column(
      children: [
        for (var index = 0; index < visibleCount; index++) ...[
          _buildActivityItem(
            transaction: transactions[index],
            onTap: () => widget.onShowDetails(transactions[index].signature),
          ),
          if (index < visibleCount - 1) const SizedBox(height: 16),
        ],
        if (hasMore) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _showAll = !_showAll),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _showAll ? 'Show less' : 'Show more',
                style: AppTheme.sansBody(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.seedVaultTeal,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityItem({
    required WalletTransaction transaction,
    required VoidCallback onTap,
  }) {
    final isSent = transaction.isSent;
    final isSuccess = transaction.isSuccessful;

    // Curated theme colors - strictly NO red, NO green
    // Received: Seed Vault Cyan | Sent: Silver Titanium
    final badgeBgColor = isSent
        ? const Color(0xFFD6E2E4).withValues(alpha: 0.08)
        : const Color(0xFF4FA8B7).withValues(alpha: 0.12);
    final borderColor = isSent
        ? const Color(0xFFD6E2E4).withValues(alpha: 0.20)
        : const Color(0xFF4FA8B7).withValues(alpha: 0.28);
    final iconColor =
        isSent ? const Color(0xFFD6E2E4) : const Color(0xFF4FA8B7);
    final iconData =
        isSent ? Icons.north_east_rounded : Icons.south_west_rounded;

    // Amount text color: Cyan for received (+), Silver Titanium for sent (-)
    final amountColor = !isSuccess
        ? AppTheme.textSecondary
        : (isSent ? const Color(0xFFD6E2E4) : const Color(0xFF4FA8B7));

    final title = transaction.title;
    final subtitle = widget.subtitleBuilder(transaction);

    return AnimatedPressable(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Icon(iconData, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sansBody(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sansBody(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                transaction.formattedAmount,
                style: AppTheme.sansBody(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isSuccess ? 'Confirmed' : 'Failed',
                style: AppTheme.sansBody(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: isSuccess
                      ? AppTheme.textSecondary.withValues(alpha: 0.7)
                      : const Color(0xFF759197),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
