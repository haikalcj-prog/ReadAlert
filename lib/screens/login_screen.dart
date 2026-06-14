import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';

// ════════════════════════════════════════════════════════════
//  LOGIN SCREEN — ReadAlert
// ════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePass = true;
  String? _errorMsg;

  static const Color _navy = Color(0xFF050D1F);
  static const Color _purple = Color(0xFF7B3FE4);
  static const Color _cyan = Color(0xFF00C6FF);
  static const Color _pink = Color(0xFFD134B6);

  late AnimationController _floatCtrl;
  late AnimationController _staggerCtrl;
  late Animation<double> _floatAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool get _busy => _isLoading || _isGoogleLoading;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(
      begin: -8,
      end: 8,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
    _floatCtrl.dispose();
    _staggerCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  String? _validateLogin() {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty) return 'Please enter your email.';
    if (!_isValidEmail(email)) return 'Please enter a valid email address.';
    if (password.isEmpty) return 'Please enter your password.';

    return null;
  }

  Future<void> _login() async {
    if (_busy) return;

    final validationError = _validateLogin();
    if (validationError != null) {
      setState(() => _errorMsg = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      await _auth.login(_emailCtrl.text.trim(), _passwordCtrl.text.trim());
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
      await _auth.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _errorMsg = _parseError(e.toString()));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  String _parseError(String raw) {
    final error = raw.toLowerCase();

    if (error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (error.contains('user-not-found'))
      return 'No account found for that email.';
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

    return 'Login failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _navy,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: AuthStarfieldPainter())),
          const Positioned(
            top: -80,
            left: -60,
            child: AuthGlowOrb(color: _purple, size: 280, opacity: 0.18),
          ),
          const Positioned(
            top: 60,
            right: -80,
            child: AuthGlowOrb(color: _cyan, size: 220, opacity: 0.12),
          ),
          const Positioned(
            bottom: -60,
            right: 40,
            child: AuthGlowOrb(color: _pink, size: 200, opacity: 0.14),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height - MediaQuery.of(context).padding.top,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          AnimatedBuilder(
                            animation: _floatAnim,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(0, _floatAnim.value),
                              child: child,
                            ),
                            child: Column(
                              children: [
                                const AuthLogoBadge(),
                                const SizedBox(height: 14),
                                ShaderMask(
                                  shaderCallback: (b) => const LinearGradient(
                                    colors: [_purple, _cyan],
                                  ).createShader(b),
                                  child: const Text(
                                    'ReadAlert',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Read | Track | Gamify',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.38),
                                    fontSize: 13,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          AuthGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Welcome back',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sign in to continue your progress',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 28),
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
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onSubmitted: (_) => _login(),
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
                                if (_errorMsg != null) ...[
                                  const SizedBox(height: 14),
                                  AuthErrorBox(message: _errorMsg!),
                                ],
                                const SizedBox(height: 28),
                                AuthGradientButton(
                                  label: 'Sign In',
                                  isLoading: _isLoading,
                                  onTap: _login,
                                ),
                                const SizedBox(height: 18),
                                const AuthDivider(),
                                const SizedBox(height: 18),
                                AuthGoogleButton(
                                  isLoading: _isGoogleLoading,
                                  onTap: _signInWithGoogle,
                                ),
                                const SizedBox(height: 18),
                                Center(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account? ",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.42),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _busy
                                            ? null
                                            : () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const RegisterScreen(),
                                                ),
                                              ),
                                        child: Text(
                                          'Create one',
                                          style: TextStyle(
                                            color: _cyan.withOpacity(
                                              _busy ? 0.35 : 0.95,
                                            ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
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
