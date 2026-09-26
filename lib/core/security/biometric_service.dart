import 'package:local_auth/local_auth.dart';

class BiometricAuthResult {
  final bool isAuthenticated;
  final String? failureReason;

  const BiometricAuthResult({
    required this.isAuthenticated,
    this.failureReason,
  });
}

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<BiometricAuthResult> authenticate({
    required String reason,
  }) async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        return const BiometricAuthResult(
          isAuthenticated: false,
          failureReason:
              'No biometric authentication is available on this phone.',
        );
      }

      final available = await _auth.getAvailableBiometrics();
      if (available.isEmpty) {
        return const BiometricAuthResult(
          isAuthenticated: false,
          failureReason: 'No fingerprint or face is enrolled on this phone.',
        );
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return BiometricAuthResult(
        isAuthenticated: authenticated,
        failureReason: authenticated
            ? null
            : 'Biometric authentication was cancelled or rejected.',
      );
    } catch (e) {
      return BiometricAuthResult(
        isAuthenticated: false,
        failureReason: 'Biometric authentication error: $e',
      );
    }
  }
}
