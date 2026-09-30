import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../wallet/domain/models/financial_insights.dart';
import '../../../wallet/services/financial_insights_service.dart';
import '../../../wallet/services/wallet_adapter_service.dart';

/// A card displaying the user's financial flow (Received, Spent, Network Fees)
/// with a multi-segment circular fill distribution and persistent caching.
///
/// Designed with human fintech craftsmanship:
/// - Palette follows Seed Vault theme: Seed Vault Cyan (Received), Silver Titanium (Spent), Steel Slate (Fees).
/// - Completely free of generic AI badges (no "Verified" / "Cached" pills) or redundant refresh buttons.
/// - Refreshing happens exclusively on dashboard pull-down-to-refresh.
class FinancialInsightsCard extends StatefulWidget {
  const FinancialInsightsCard({super.key});

  @override
  State<FinancialInsightsCard> createState() => _FinancialInsightsCardState();
}

class _FinancialInsightsCardState extends State<FinancialInsightsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _sweepAnimation;

  // Curated theme colors - strictly NO purple, NO green
  static const Color _receivedColor =
      Color(0xFF4FA8B7); // Seed Vault Accent Cyan
  static const Color _spentColor = Color(0xFFD6E2E4); // Silver Titanium
  static const Color _feesColor = Color(0xFF759197); // Steel Slate
  static const Color _trackColor = Color(0xFF18282B); // Deep Slate Ring Track

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _sweepAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    WalletAdapterService.instance.fullAddressNotifier
        .addListener(_onAddressChanged);
    WalletAdapterService.instance.isConnectedNotifier
        .addListener(_onAddressChanged);
    WalletAdapterService.instance.solBalanceNotifier
        .addListener(_onAddressChanged);
    FinancialInsightsService.instance.insightsNotifier
        .addListener(_onInsightsUpdated);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  void _onAddressChanged() {
    if (mounted) {
      _load();
    }
  }

  void _onInsightsUpdated() {
    if (mounted) {
      _animController.forward(from: 0.0);
    }
  }

  void _load() {
    final addr = WalletAdapterService.instance.fullAddressNotifier.value;
    if (addr.isNotEmpty) {
      FinancialInsightsService.instance.loadInsights();
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    WalletAdapterService.instance.fullAddressNotifier
        .removeListener(_onAddressChanged);
    WalletAdapterService.instance.isConnectedNotifier
        .removeListener(_onAddressChanged);
    WalletAdapterService.instance.solBalanceNotifier
        .removeListener(_onAddressChanged);
    FinancialInsightsService.instance.insightsNotifier
        .removeListener(_onInsightsUpdated);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: WalletAdapterService.instance.isConnectedNotifier,
      builder: (context, isConnected, _) {
        if (!isConnected) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<FinancialInsights>(
          valueListenable: FinancialInsightsService.instance.insightsNotifier,
          builder: (context, insights, _) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.outlineBorder,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clean Header (No AI pills, No refresh buttons)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _receivedColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.pie_chart_outline_rounded,
                              size: 18,
                              color: _receivedColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Financial Flow',
                            style: AppTheme.serifHeading(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ValueListenableBuilder<FinancialInsightsSyncStatus>(
                        valueListenable: FinancialInsightsService
                            .instance.syncStatusNotifier,
                        builder: (context, status, _) {
                          final statusText = switch (status) {
                            FinancialInsightsSyncStatus.checking => 'Checking',
                            FinancialInsightsSyncStatus.collecting =>
                              'Collecting',
                            FinancialInsightsSyncStatus.synced =>
                              'Synced · ${insights.transactionCount}',
                            FinancialInsightsSyncStatus.retryPending =>
                              'Will resume',
                            FinancialInsightsSyncStatus.ready => 'Not synced',
                          };
                          final isWorking = status ==
                                  FinancialInsightsSyncStatus.checking ||
                              status == FinancialInsightsSyncStatus.collecting;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                statusText,
                                style: AppTheme.sansBody(
                                  fontSize: 12,
                                  color: isWorking
                                      ? _receivedColor
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              if (isWorking) ...[
                                const SizedBox(height: 4),
                                const SizedBox(
                                  width: 76,
                                  child: LinearProgressIndicator(
                                    minHeight: 2,
                                    backgroundColor: _trackColor,
                                    color: _receivedColor,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Circular Distribution + Categories Layout
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 340;

                      if (isCompact) {
                        return Column(
                          children: [
                            _buildCircularChart(insights),
                            const SizedBox(height: 22),
                            _buildCategoryBreakdown(insights),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left: Circular Fill Distribution Chart
                          _buildCircularChart(insights),
                          const SizedBox(width: 22),
                          // Right: Metrics Breakdown
                          Expanded(
                            child: _buildCategoryBreakdown(insights),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // Divider
                  Container(
                    height: 1,
                    color: AppTheme.outlineBorder.withValues(alpha: 0.6),
                  ),

                  const SizedBox(height: 14),

                  // Footer: Net Flow
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Balance Flow',
                        style: AppTheme.sansBody(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        insights.formattedNetFlow,
                        style: AppTheme.sansBody(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: insights.netFlow >= 0
                              ? _receivedColor
                              : const Color(0xFFE57373),
                        ),
                      ),
                    ],
                  ),

                  // First-time user tip
                  if (insights.transactionCount == 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: _receivedColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _receivedColor.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: _receivedColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Confirmed transactions appear here after the next scheduled Devnet sync.',
                              style: AppTheme.sansBody(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Custom circular progress donut showing money distribution
  Widget _buildCircularChart(FinancialInsights insights) {
    return AnimatedBuilder(
      animation: _sweepAnimation,
      builder: (context, child) {
        return SizedBox(
          width: 112,
          height: 112,
          child: CustomPaint(
            painter: _CircularDistributionPainter(
              receivedRatio: insights.receivedRatio,
              spentRatio: insights.spentRatio,
              feesRatio: insights.feesRatio,
              animationProgress: _sweepAnimation.value,
              receivedColor: _receivedColor,
              spentColor: _spentColor,
              feesColor: _feesColor,
              trackColor: _trackColor,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    insights.totalVolume > 0
                        ? insights.totalVolume.toStringAsFixed(2)
                        : '0.00',
                    style: AppTheme.serifHeading(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'SOL VOLUME',
                    style: AppTheme.sansBody(
                      fontSize: 8.5,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Breakdown list for Received, Spent, and Network Fees
  Widget _buildCategoryBreakdown(FinancialInsights insights) {
    final totalVol = insights.totalVolume;
    final rPct = totalVol > 0 ? (insights.receivedRatio * 100).round() : 0;
    final sPct = totalVol > 0 ? (insights.spentRatio * 100).round() : 0;
    final fPct =
        totalVol > 0 ? (insights.feesRatio * 100).toStringAsFixed(1) : '0';

    return Column(
      children: [
        _buildMetricItem(
          color: _receivedColor,
          label: 'Received',
          amount: insights.formattedReceived,
          percentage: '$rPct%',
        ),
        const SizedBox(height: 12),
        _buildMetricItem(
          color: _spentColor,
          label: 'Spent',
          amount: insights.formattedSpent,
          percentage: '$sPct%',
        ),
        const SizedBox(height: 12),
        _buildMetricItem(
          color: _feesColor,
          label: 'Network Fees',
          amount: insights.formattedFees,
          percentage: '$fPct%',
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required Color color,
    required String label,
    required String amount,
    required String percentage,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTheme.sansBody(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    amount,
                    style: AppTheme.sansBody(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      percentage,
                      style: AppTheme.sansBody(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter for drawing animated circular fill segments
class _CircularDistributionPainter extends CustomPainter {
  final double receivedRatio;
  final double spentRatio;
  final double feesRatio;
  final double animationProgress;
  final Color receivedColor;
  final Color spentColor;
  final Color feesColor;
  final Color trackColor;

  _CircularDistributionPainter({
    required this.receivedRatio,
    required this.spentRatio,
    required this.feesRatio,
    required this.animationProgress,
    required this.receivedColor,
    required this.spentColor,
    required this.feesColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Draw background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    final totalRatio = receivedRatio + spentRatio + feesRatio;
    if (totalRatio <= 0) return;

    // Normalize ratios to ensure full 360-degree sum
    final normR = receivedRatio / totalRatio;
    final normS = spentRatio / totalRatio;
    final normF = feesRatio / totalRatio;

    // Subtle gap between segments
    const gap = 0.06;
    const fullCircle = 2 * math.pi;

    // Count how many non-zero segments exist
    int activeSegments = 0;
    if (normR > 0) activeSegments++;
    if (normS > 0) activeSegments++;
    if (normF > 0) activeSegments++;

    final effectiveGap = activeSegments > 1 ? gap : 0.0;
    final availableAngle = fullCircle - (activeSegments * effectiveGap);

    double startAngle = -math.pi / 2; // start from 12 o'clock

    // Helper to draw an arc segment
    void drawSegment(double ratio, Color color) {
      if (ratio <= 0) return;
      final sweep = (ratio * availableAngle) * animationProgress;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );

      startAngle += sweep + effectiveGap;
    }

    // Draw Received segment (Seed Vault Cyan)
    drawSegment(normR, receivedColor);

    // Draw Spent segment (Silver Titanium)
    drawSegment(normS, spentColor);

    // Draw Network Fees segment (Steel Slate)
    drawSegment(normF, feesColor);
  }

  @override
  bool shouldRepaint(covariant _CircularDistributionPainter oldDelegate) {
    return oldDelegate.receivedRatio != receivedRatio ||
        oldDelegate.spentRatio != spentRatio ||
        oldDelegate.feesRatio != feesRatio ||
        oldDelegate.animationProgress != animationProgress;
  }
}
