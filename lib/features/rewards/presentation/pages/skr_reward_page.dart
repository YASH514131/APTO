import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/animation/fast_rolling_counter_text.dart';
import '../../../../core/animation/shimmer_loading.dart';
import '../../../wallet/services/wallet_adapter_service.dart';
import '../../models/reward_history_item.dart';
import '../../services/skr_reward_service.dart';
import '../dialogs/redemption_success_dialog.dart';
import '../utils/skr_format_utils.dart';
import '../../../../shared/widgets/app_error_dialog.dart';

class SkrRewardPage extends StatefulWidget {
  const SkrRewardPage({super.key});

  @override
  State<SkrRewardPage> createState() => _SkrRewardPageState();
}

class _SkrRewardPageState extends State<SkrRewardPage>
    with SingleTickerProviderStateMixin {
  bool _isFetchingBalance = false;
  Map<String, dynamic>? _balanceData;
  String? _errorMessage;

  late AnimationController _pageAnimController;
  late Animation<double> _heroCardScale;
  late Animation<double> _heroCardFade;
  late Animation<Offset> _totalEarnedSlide;
  late Animation<double> _totalEarnedFade;
  late Animation<Offset> _historySlide;
  late Animation<double> _historyFade;

  @override
  void initState() {
    super.initState();
    _pageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _heroCardScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _pageAnimController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _heroCardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pageAnimController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _totalEarnedSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageAnimController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _totalEarnedFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pageAnimController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    _historySlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageAnimController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _historyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pageAnimController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
      ),
    );

    _pageAnimController.forward();
    _fetchBalance();
    WalletAdapterService.instance.fullAddressNotifier
        .addListener(_onWalletChanged);
  }

  @override
  void dispose() {
    _pageAnimController.dispose();
    WalletAdapterService.instance.fullAddressNotifier
        .removeListener(_onWalletChanged);
    super.dispose();
  }

  void _onWalletChanged() {
    if (mounted) {
      _fetchBalance();
    }
  }

  String get _currentWalletPubkey {
    final pubkey =
        WalletAdapterService.instance.fullAddressNotifier.value.trim();
    return pubkey.isNotEmpty ? pubkey : 'demo-wallet-1';
  }

  double get _availableSkr {
    final raw = _balanceData?['accruedSkr'] ??
        _balanceData?['accrued_skr'] ??
        _balanceData?['balance'] ??
        0.0;
    return (raw as num).toDouble();
  }

  double get _lifetimeSkr {
    final raw = _balanceData?['lifetimeEarnedSkr'] ??
        _balanceData?['lifetime_earned_skr'] ??
        0.0;
    return (raw as num).toDouble();
  }

  Future<void> _fetchBalance() async {
    final pubkey = _currentWalletPubkey;
    setState(() {
      _isFetchingBalance = true;
      _errorMessage = null;
    });

    try {
      final res = await SkrRewardService.instance.getBalance(pubkey);
      if (mounted) {
        setState(() {
          _balanceData = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppErrorDialog.friendlyMessage(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingBalance = false);
      }
    }
  }

  Widget _buildAngledSkrLogo({double size = 28, double angle = -0.18}) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.seedVaultTeal.withValues(alpha: 0.8),
              const Color(0xFF092930),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: [
            BoxShadow(
              color: AppTheme.seedVaultTeal.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1.5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.26),
          child: Image.asset(
            'lib/assets/images/skr_logo.jpg',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              color: AppTheme.seedVaultTeal,
              child: const Icon(Icons.star, color: Colors.black, size: 16),
            ),
          ),
        ),
      ),
    );
  }

  void _openRedeemSheet() {
    final available = _availableSkr;
    final redeemController = TextEditingController(
      text: available > 0 ? formatSkrAmount(math.min(available, 0.6)) : '0.1',
    );
    bool isSubmitting = false;
    String? sheetError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: AppTheme.seedVaultTeal.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D3B43),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildAngledSkrLogo(size: 24, angle: -0.15),
                        const SizedBox(width: 10),
                        Text(
                          'Redeem SKR',
                          style: AppTheme.serifHeading(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${formatSkrAmount(available)} SKR Available',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Destination Wallet (Solana Mainnet)',
                  style: AppTheme.sansBody(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF091C22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF122C34)),
                  ),
                  child: Row(
                    children: [
                      _buildAngledSkrLogo(size: 18, angle: -0.12),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentWalletPubkey,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Amount to Redeem (SKR)',
                  style: AppTheme.sansBody(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: redeemController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF091C22),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF122C34)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppTheme.seedVaultTeal),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF143038),
                        foregroundColor: AppTheme.seedVaultTeal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final max = math.min(available, 0.6);
                        redeemController.text =
                            max > 0 ? formatSkrAmount(max) : '0.6';
                      },
                      child: const Text(
                        'MAX (0.6)',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (sheetError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    sheetError!,
                    style:
                        const TextStyle(color: Color(0xFFE57373), fontSize: 11),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.seedVaultTeal,
                      foregroundColor: const Color(0xFF031016),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(redeemController.text.trim()) ??
                                    0.0;
                            if (amount <= 0) {
                              setSheetState(
                                  () => sheetError = 'Enter an amount > 0');
                              return;
                            }
                            if (amount > available && available > 0) {
                              setSheetState(() => sheetError =
                                  'Exceeds available balance ($available SKR)');
                              return;
                            }

                            setSheetState(() {
                              isSubmitting = true;
                              sheetError = null;
                            });

                            try {
                              await SkrRewardService.instance.redeem(
                                userPubkey: _currentWalletPubkey,
                                amountSkr: amount,
                              );

                              await SkrRewardService.instance.addHistoryRecord(
                                title: 'Reward Redemption',
                                amountSkr: amount,
                                isCredit: false,
                              );

                              if (sheetCtx.mounted) {
                                Navigator.of(sheetCtx).pop();
                              }
                              await _fetchBalance();
                              if (mounted) {
                                RedemptionSuccessDialog.show(
                                  context,
                                  amountSkr: amount,
                                  destinationWallet: _currentWalletPubkey,
                                );
                              }
                            } catch (e) {
                              setSheetState(() {
                                isSubmitting = false;
                                sheetError = AppErrorDialog.friendlyMessage(
                                  e.toString(),
                                );
                              });
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color.fromARGB(255, 252, 252, 252),
                            ),
                          )
                        : const Text(
                            'Confirm Redemption',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color.fromARGB(255, 252, 252, 252),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031016),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'lib/assets/images/logo.jpg',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Rewards',
              style: AppTheme.serifHeading(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/assets/images/reward.jpg',
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
              backgroundColor: const Color(0xFF091C22),
              onRefresh: _fetchBalance,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 10,
                  bottom: MediaQuery.of(context).padding.bottom + 90,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFFE6A35C).withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 20,
                              color: Color(0xFFE6A35C),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rewards could not refresh',
                                    style: AppTheme.sansBody(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _errorMessage!,
                                    style: AppTheme.sansBody(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Try again',
                              onPressed:
                                  _isFetchingBalance ? null : _fetchBalance,
                              icon: const Icon(Icons.refresh_rounded),
                              color: const Color(0xFFE6A35C),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 1. Available Rewards Hero Card with Fluid Entrance Scale & Fade
                    ScaleTransition(
                      scale: _heroCardScale,
                      child: FadeTransition(
                        opacity: _heroCardFade,
                        child: _buildAvailableRewardsCard(),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 2. Total Earned Metric with Fluid Slide & Fade
                    SlideTransition(
                      position: _totalEarnedSlide,
                      child: FadeTransition(
                        opacity: _totalEarnedFade,
                        child: _buildTotalEarnedSection(),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 3. Reward History Section with Fluid Slide & Fade
                    SlideTransition(
                      position: _historySlide,
                      child: FadeTransition(
                        opacity: _historyFade,
                        child: _buildRewardHistorySection(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableRewardsCard() {
    final available = _availableSkr;
    final balanceRow = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        FastRollingCounterText(
          targetValue: available,
          decimals: 5,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'SKR',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: AppTheme.seedVaultTeal.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.seedVaultTeal.withValues(alpha: 0.12),
              blurRadius: 28,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Enlarged, angled & faded background watermark SKR logo imprint
            Positioned(
              right: -28,
              top: -24,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: -0.24,
                  child: Opacity(
                    opacity: 0.16,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppTheme.seedVaultTeal.withValues(alpha: 0.2),
                            blurRadius: 32,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: Image.asset(
                          'lib/assets/images/skr_logo.jpg',
                          width: 155,
                          height: 155,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 155,
                            height: 155,
                            color: AppTheme.seedVaultTeal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AVAILABLE REWARDS',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 12),
                if (_isFetchingBalance && _balanceData == null)
                  const ShimmerLoading(
                    isLoading: true,
                    baseColor: Color(0xFF0C242B),
                    highlightColor: Color(0xFF286472),
                    child: Row(
                      children: [
                        ShimmerBox(width: 160, height: 40, borderRadius: 8),
                        SizedBox(width: 8),
                        ShimmerBox(width: 46, height: 22, borderRadius: 6),
                      ],
                    ),
                  )
                else if (_isFetchingBalance)
                  ShimmerLoading(
                    isLoading: true,
                    baseColor: Colors.white,
                    highlightColor: AppTheme.seedVaultTeal,
                    child: balanceRow,
                  )
                else
                  balanceRow,
                const SizedBox(height: 4),
                const Text(
                  'Ready to redeem',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),

                // Redeem Full-Width Pill Button
                InkWell(
                  onTap: _openRedeemSheet,
                  borderRadius: BorderRadius.circular(28),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.seedVaultTeal,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.seedVaultTeal.withValues(alpha: 0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.card_giftcard_rounded,
                          color: Color.fromARGB(255, 255, 255, 255),
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Redeem',
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Color.fromARGB(255, 255, 255, 255),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalEarnedSection() {
    final lifetime = _lifetimeSkr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total Earned',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        // Fast rolling number counter animation (0.00 -> total earned SKR)
        FastRollingCounterText(
          targetValue: lifetime,
          decimals: 5,
          suffix: 'SKR',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRewardHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reward History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<List<RewardHistoryItem>>(
          valueListenable: SkrRewardService.instance.historyNotifier,
          builder: (context, historyList, _) {
            if (historyList.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF10282F)),
                ),
                child: const Center(
                  child: Text(
                    'No rewards yet. Tap and pay to earn your first reward!',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historyList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = historyList[index];
                return _buildHistoryCard(item);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryCard(RewardHistoryItem item) {
    final prefix = item.isCredit ? '+' : '-';
    final amountColor =
        item.isCredit ? AppTheme.seedVaultTeal : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10282F),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.dateText,
                  style: const TextStyle(
                    color: Color(0xFF6C878D),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$prefix ${formatSkrAmount(item.amountSkr)} SKR',
            style: TextStyle(
              color: amountColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
