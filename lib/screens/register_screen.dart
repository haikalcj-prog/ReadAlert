import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth_widgets.dart';
import 'main_screen.dart';

// ════════════════════════════════════════════════════════════
//  REGISTER SCREEN — ReadAlert
// ════════════════════════════════════════════════════════════
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _errorMsg;

  static const Color _navy = Color(0xFF050D1F);
  static const Color _purple = Color(0xFF7B3FE4);
  static const Color _cyan = Color(0xFF00C6FF);
  static const Color _pink = Color(0xFFD134B6);

  late AnimationController _staggerCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool get _busy => _isLoading || _isGoogleLoading;

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(parent: _staggerCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _staggerCtrl, curve: Curves.easeOutCubic),
        );

    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  String? _validateRegister() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty) return 'Please enter your full name.';
    if (name.length < 2) return 'Name must be at least 2 characters.';
    if (email.isEmpty) return 'Please enter your email.';
    if (!_isValidEmail(email)) return 'Please enter a valid email address.';
    if (password.isEmpty) return 'Please enter your password.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (confirm.isEmpty) return 'Please confirm your password.';
    if (password != confirm) return 'Passwords do not match.';

    return null;
  }

  Future<void> _register() async {
    if (_busy) return;

    final validationError = _validateRegister();
    if (validationError != null) {
      setState(() => _errorMsg = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final user = await _auth.register(
        _nameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );

      if (user != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = _parseError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;

    setState(() {
      _isGoogleLoading = true;
      _errorMsg = null;
    });

    try {
      final user = await _auth.signInWithGoogle();

      if (user != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = _parseError(e.toString()));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  String _parseError(String raw) {
    final error = raw.toLowerCase();

    if (error.contains('email-already-in-use')) {
      return 'An account already exists for this email.';
    }
    if (error.contains('weak-password')) return 'Password is too weak.';
    if (error.contains('invalid-email')) return 'Please enter a valid email.';
    if (error.contains('network')) return 'No internet connection.';
    if (error.contains('popup-closed-by-user') ||
        error.contains('canceled') ||
        error.contains('cancelled')) {
      return 'Google sign-in was cancelled.';
    }
    if (error.contains('missing id token')) {
      return 'Google sign-in setup is incomplete. Please check Firebase SHA-1 and google-services.json.';
    }
    if (error.contains('api_exception: 10') ||
        error.contains('developer_error')) {
      return 'Google sign-in setup issue. Check SHA-1 and google-services.json.';
    }

    return 'Registration failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: AuthStarfieldPainter())),
          const Positioned(
            top: -60,
            right: -60,
            child: AuthGlowOrb(color: _cyan, size: 240, opacity: 0.14),
          ),
          const Positioned(
            bottom: 40,
            left: -60,
            child: AuthGlowOrb(color: _purple, size: 260, opacity: 0.16),
          ),
          const Positioned(
            top: 200,
            left: -40,
            child: AuthGlowOrb(color: _pink, size: 180, opacity: 0.10),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _busy ? null : () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.10),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white.withOpacity(0.70),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.70),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            const AuthMiniLogo(),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (b) => const LinearGradient(
                                      colors: [_purple, _cyan],
                                    ).createShader(b),
                                    child: const Text(
                                      'Join ReadAlert',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Start your reading journey',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.35),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        AuthGlassCard(
                          child: Column(
                            children: [
                              AuthInputField(
                                label: 'Full Name',
                                hint: 'Your name',
                                controller: _nameCtrl,
                                icon: Icons.person_outline_rounded,
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                autocorrect: false,
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 16),
                              AuthInputField(
                                label: 'Email',
                                hint: 'your@email.com',
                                controller: _emailCtrl,
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                              ),
                              const SizedBox(height: 16),
                              AuthInputField(
                                label: 'Password',
                                hint: '••••••••',
                                controller: _passwordCtrl,
                                icon: Icons.lock_outline_rounded,
                                obscure: _obscurePass,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(
                                    () => _obscurePass = !_obscurePass,
                                  ),
                                  child: Icon(
                                    _obscurePass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white.withOpacity(0.35),
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              AuthInputField(
                                label: 'Confirm Password',
                                hint: '••••••••',
                                controller: _confirmCtrl,
                                icon: Icons.lock_outline_rounded,
                                obscure: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                onSubmitted: (_) => _register(),
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                  child: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white.withOpacity(0.35),
                                    size: 20,
                                  ),
                                ),
                              ),
                              if (_errorMsg != null) ...[
                                const SizedBox(height: 14),
                                AuthErrorBox(message: _errorMsg!),
                              ],
                              const SizedBox(height: 28),
                              AuthGradientButton(
                                label: 'Create Account',
                                isLoading: _isLoading,
                                onTap: _register,
                              ),
                              const SizedBox(height: 18),
                              const AuthDivider(),
                              const SizedBox(height: 18),
                              AuthGoogleButton(
                                isLoading: _isGoogleLoading,
                                onTap: _signInWithGoogle,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: GestureDetector(
                            onTap: _busy ? null : () => Navigator.pop(context),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Already have an account? ',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.35),
                                      fontSize: 13,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Sign In',
                                    style: TextStyle(
                                      color: _purple.withOpacity(0.90),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
