import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/constants/solana_config.dart';
import 'features/payer/presentation/pages/home_dashboard_page.dart';
import 'features/terminal/presentation/pages/terminal_page.dart';
import 'features/payer/presentation/pages/tap_reader_page.dart';
import 'core/services/apto_notification_service.dart';
import 'core/services/apto_fcm_service.dart';
import 'core/services/apto_background_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/rewards/presentation/pages/skr_reward_page.dart';
import 'features/wallet/presentation/pages/seed_vault_auth_page.dart';
import 'features/wallet/services/wallet_adapter_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Android system notification service & channel
  await AptoNotificationService.instance.initialize();

  // Initialize 24/7 On-Device Background Service for closed-app alerts
  try {
    await AptoBackgroundService.instance.initialize();
  } catch (e) {
    debugPrint('Background service initialization note: $e');
  }

  // Initialize Firebase & FCM Cloud Messaging
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AptoFcmService.instance.initialize();
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  // Load environment variables from .env if present

  try {
    await dotenv.load(fileName: ".env");
    final envKey = dotenv.env['HELIUS_API_KEY'];
    if (envKey != null && envKey.trim().isNotEmpty) {
      SolanaConfig.heliusApiKey = envKey.trim();
    }
  } catch (e) {
    debugPrint('Note: .env file not loaded: $e');
  }

  // Prevent SocketException / DNS host lookup failures when offline or on poor network
  GoogleFonts.config.allowRuntimeFetching = false;

  await WalletAdapterService.instance.initialize();
  runApp(const AptoApp());
}

class AptoApp extends StatelessWidget {
  const AptoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APTO - Solana Tap-to-Pay',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomeDashboardPage(),
    TapReaderPage(),
    TerminalPage(),
    SkrRewardPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Prompt for notification permissions on Android 13+ / iOS once UI is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AptoNotificationService.instance.requestPermission();

      // Self-heal: restart background service if it was killed by Android
      final addr = WalletAdapterService.instance.fullAddressNotifier.value;
      if (addr.isNotEmpty) {
        AptoBackgroundService.instance.ensureRunning(addr);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: WalletAdapterService.instance.isConnectedNotifier,
      builder: (context, isConnected, child) {
        if (!isConnected) {
          return SeedVaultAuthPage(
            onConnected: () {
              setState(() {
                _selectedIndex = 0;
              });
            },
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF031016),
          extendBody: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Full-screen page content (behind the nav)
              Positioned.fill(
                child: _pages[_selectedIndex],
              ),

              // Floating bottom nav bar
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppTheme.background.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppTheme.seedVaultTeal.withValues(alpha: 0.25),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(
                            icon: Icons.account_balance_wallet_outlined,
                            activeIcon: Icons.account_balance_wallet,
                            label: 'Wallet',
                            index: 0,
                          ),
                          _buildNavItem(
                            icon: Icons.nfc,
                            activeIcon: Icons.nfc,
                            label: 'Tap & Pay',
                            index: 1,
                          ),
                          _buildNavItem(
                            icon: Icons.point_of_sale_outlined,
                            activeIcon: Icons.point_of_sale,
                            label: 'Terminal',
                            index: 2,
                          ),
                          _buildNavItem(
                            icon: Icons.stars_outlined,
                            activeIcon: Icons.stars_rounded,
                            label: 'Rewards',
                            index: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.seedVaultTeal.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppTheme.seedVaultTeal : AppTheme.slateGray,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.seedVaultTeal : AppTheme.slateGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
