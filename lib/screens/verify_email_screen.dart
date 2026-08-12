import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

/// Shown by [AuthGate] whenever the signed-in user has not yet verified
/// their email. The user must verify (via the link Firebase emails them)
/// before they can proceed to onboarding.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isSending = false;
  bool _isChecking = false;
  String? _message;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _resendEmail() async {
    setState(() {
      _isSending = true;
      _message = null;
    });
    try {
      final user = _user;
      if (user == null) return;
      await user.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _message = 'Verification email sent! Check your inbox.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _message = e.code == 'too-many-requests'
            ? 'Too many requests. Please try again in a few minutes.'
            : 'Could not send the email. Please try again.';
      });
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });
    try {
      final user = _user;
      if (user == null) return;
      // Refresh the local user to pick up the latest emailVerified state.
      // When it flips to true, the AuthGate's userChanges() stream rebuilds
      // and routes the user into onboarding automatically.
      await user.reload();
      if (!mounted) return;
      if (user.emailVerified) {
        setState(() => _isChecking = false);
      } else {
        setState(() {
          _isChecking = false;
          _message =
              'Not verified yet. Open the link we emailed you, then try again.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _message = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = _user?.email ?? 'your email';
    return Scaffold(
      backgroundColor: context.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [context.accent, const Color(0xFF38BDF8)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Verify your email',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a verification link to\n$email.\n'
                    'Open it in your inbox and click the link to activate '
                    'your account.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: context.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Status message
                  if (_message != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _message!.startsWith('Verification')
                            ? context.success.withValues(alpha: 0.1)
                            : context.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _message!.startsWith('Verification')
                              ? context.success.withValues(alpha: 0.3)
                              : context.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _message!.startsWith('Verification')
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            color: _message!.startsWith('Verification')
                                ? context.success
                                : context.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _message!,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Continue once verified
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isChecking ? null : _checkVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isChecking
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "I've verified my email",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Resend the verification email
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isSending ? null : _resendEmail,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.accent,
                        side: BorderSide(color: context.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Resend email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sign out so the user can switch accounts
                  TextButton(
                    onPressed: _signOut,
                    child: Text(
                      'Use a different account',
                      style: TextStyle(color: context.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
