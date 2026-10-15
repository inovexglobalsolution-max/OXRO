import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_button.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/auth/presentation/screens/otp_screen.dart';

/// 04 Login / Sign Up — reference minimal white style, brand centered.
/// Segmented tabs: Login (email) | Sign Up (name + email + referral).
/// Content block vertically centered; email-only, no phone.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static final _emailRegex =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

  bool _isSignup = false;

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  String? _emailError;
  String? _nameError;
  String? _referralError;

  late final AnimationController _shake;
  late final AnimationController _bg;
  late final AnimationController _entry;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bg = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _referralCtrl.dispose();
    _shake.dispose();
    _bg.dispose();
    _entry.dispose();
    super.dispose();
  }

  bool get _validEmail =>
      _emailRegex.hasMatch(_emailCtrl.text.trim());

  void _fail() => _shake.forward(from: 0);

  void _submit() {
    final emailOk = _validEmail;
    setState(() {
      _emailError = emailOk
          ? null
          : (_emailCtrl.text.trim().isEmpty
              ? 'Enter your email address'
              : 'Enter valid email address');
      if (_isSignup) {
        final name = _nameCtrl.text.trim();
        _nameError = RegExp(r'^[A-Za-z][A-Za-z ]{2,}$').hasMatch(name)
            ? null
            : (name.isEmpty
                ? 'Enter your full name'
                : 'Enter a valid name (min 3 letters)');
        final ref = _referralCtrl.text.trim();
        _referralError =
            ref.isEmpty || RegExp(r'^[A-Za-z0-9]{6,}$').hasMatch(ref)
                ? null
                : 'Enter valid referral code (min 6 chars)';
      } else {
        _nameError = null;
        _referralError = null;
      }
    });
    final ok = _isSignup
        ? (emailOk && _nameError == null && _referralError == null)
        : emailOk;
    if (!ok) {
      _fail();
      return;
    }
    FocusScope.of(context).unfocus();
    pushScreen(
      context,
      OtpScreen(
        contact: _emailCtrl.text.trim(),
        name: _isSignup ? _nameCtrl.text.trim() : null,
        isNewUser: _isSignup,
      ),
    );
  }

  InputDecoration _dec({
    required String hint,
    Widget? prefix,
    String? error,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: OxroColors.muted),
      prefixIcon: prefix,
      errorText: error,
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OxroColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OxroColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: OxroColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignup ? 'Create Account' : 'Welcome Back';
    final sub = _isSignup
        ? 'Join OXRO to shop fashion & electronics'
        : 'Login or create your account to continue';

    return Scaffold(
      backgroundColor: const Color(0xFFFFEEDF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF6), Color(0xFFFFE9D6)],
          ),
        ),
        child: Stack(
          children: [
            // Premium animated background — fills top white space.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bg,
                builder: (context, child) {
                  final t = _bg.value;
                  return Stack(
                    children: [
                      Positioned(
                        top: -70 +
                            14 * math.sin(t * math.pi * 2),
                        right: -60,
                        child: Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            color: OxroColors.primary
                                .withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 150 +
                            12 * math.cos(t * math.pi * 2),
                        left: -80,
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            color: OxroColors.blue
                                .withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -90,
                        right: -70,
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            color: OxroColors.primary
                                .withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: context.maxContentW),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  children: [
                    // Top: back button only (brand lives in big logo).
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.rs(8), vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () =>
                                Navigator.of(context)
                                    .maybePop(),
                            icon: const Icon(
                                Icons.arrow_back),
                          ),
                        ],
                      ),
                    ),
                    // Middle block — vertically centered.
                    // Scrolls on short screens instead of overflowing.
                    Expanded(
                      child: LayoutBuilder(
                        builder: (ctx, viewport) =>
                            SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: viewport.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  // Big centered logo above Welcome.
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(
                                                context.rs(18)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: OxroColors
                                                .primary
                                                .withValues(
                                                    alpha: 0.25),
                                            blurRadius: 20,
                                            offset: const Offset(
                                                0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(
                                                context.rs(18)),
                                        child: Image.asset(
                                          'assets/logo/oxro_logo.jpeg',
                                          width: (context.w * 0.16)
                                              .clamp(48.0, 72.0),
                                          height: (context.w * 0.16)
                                              .clamp(48.0, 72.0),
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err,
                                                  stack) =>
                                              Container(
                                            width: (context.w *
                                                    0.16)
                                                .clamp(48.0, 72.0),
                                            height: (context.w *
                                                    0.16)
                                                .clamp(48.0, 72.0),
                                            color:
                                                OxroColors.primary,
                                            alignment:
                                                Alignment.center,
                                            child: Text('O',
                                                style: TextStyle(
                                                    fontSize: context
                                                        .font(32),
                                                    fontWeight:
                                                        FontWeight
                                                            .w800,
                                                    color:
                                                        Colors.white)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: context.rs(10)),
                                  Center(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                          milliseconds: 250),
                                      child: Text(
                                        title,
                                        key: ValueKey(title),
                                        textAlign:
                                            TextAlign.center,
                                        style: TextStyle(
                                            fontSize:
                                                context.font(22),
                                            fontWeight:
                                                FontWeight.w800,
                                            color: OxroColors.dark),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: context.rs(4)),
                                  Center(
                                    child: Text(sub,
                                        textAlign:
                                            TextAlign.center,
                                        style: TextStyle(
                                            fontSize:
                                                context.font(13),
                                            color:
                                                OxroColors.muted)),
                                  ),
                                  SizedBox(height: context.rs(14)),
                                  // Segmented Login | Sign Up.
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(
                                            horizontal:
                                                context.padX),
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                            0xFFF1F1F4),
                                        borderRadius:
                                            BorderRadius.circular(
                                                12),
                                      ),
                                      child: Stack(
                                        children: [
                                          AnimatedAlign(
                                            alignment: _isSignup
                                                ? Alignment
                                                    .centerRight
                                                : Alignment
                                                    .centerLeft,
                                            duration:
                                                const Duration(
                                                    milliseconds:
                                                        250),
                                            curve: Curves
                                                .easeOutCubic,
                                            child:
                                                FractionallySizedBox(
                                              widthFactor: 0.5,
                                              child: Container(
                                                margin:
                                                    const EdgeInsets
                                                        .all(4),
                                                decoration:
                                                    BoxDecoration(
                                                  gradient: OxroColors
                                                      .gradient,
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              9),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child:
                                                    GestureDetector(
                                                  behavior:
                                                      HitTestBehavior
                                                          .opaque,
                                                  onTap: () =>
                                                      setState(() =>
                                                          _isSignup =
                                                              false),
                                                  child: Center(
                                                    child: Text(
                                                        'Login',
                                                        style: TextStyle(
                                                            fontSize: context.font(
                                                                14),
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                            color: _isSignup
                                                                ? OxroColors.muted
                                                                : Colors
                                                                    .white)),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child:
                                                    GestureDetector(
                                                  behavior:
                                                      HitTestBehavior
                                                          .opaque,
                                                  onTap: () =>
                                                      setState(() =>
                                                          _isSignup =
                                                              true),
                                                  child: Center(
                                                    child: Text(
                                                        'Sign Up',
                                                        style: TextStyle(
                                                            fontSize: context.font(
                                                                14),
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                            color: _isSignup
                                                                ? Colors
                                                                    .white
                                                                : OxroColors.muted)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: context.rs(14)),
                                  // Form with shake.
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(
                                            horizontal:
                                                context.padX),
                                    child: AnimatedBuilder(
                                      animation: _shake,
                                      builder:
                                          (context, child) {
                                        final dx =
                                            _shake.value == 0
                                                ? 0.0
                                                : 8 *
                                                    math.sin(_shake
                                                            .value *
                                                        math.pi *
                                                        3);
                                        return Transform
                                            .translate(
                                          offset:
                                              Offset(dx, 0),
                                          child: child,
                                        );
                                      },
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(
                                                milliseconds:
                                                    250),
                                        child: _isSignup
                                            ? _signupForm(
                                                key: const ValueKey(
                                                    'su'))
                                            : _loginForm(
                                                key: const ValueKey(
                                                    'li')),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: context.rs(14)),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(
                                            horizontal:
                                                context.padX),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                            child: Divider()),
                                        Padding(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                  horizontal:
                                                      12),
                                          child: Text(
                                              'or continue with',
                                              style: TextStyle(
                                                  fontSize: context
                                                      .font(12),
                                                  color: OxroColors
                                                      .muted)),
                                        ),
                                        const Expanded(
                                            child: Divider()),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: context.rs(12)),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(
                                            horizontal:
                                                context.padX),
                                    child: GestureDetector(
                                      onTap: () {
                                        showOxroSnack(
                                            context,
                                            'Google sign-in coming soon — use OTP for now');
                                      },
                                      child: Container(
                                        height: 50,
                                        alignment:
                                            Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12),
                                          border: Border.all(
                                              color:
                                                  OxroColors.border),
                                        ),
                                        child: Row(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 22,
                                              height: 22,
                                              alignment: Alignment
                                                  .center,
                                              decoration:
                                                  const BoxDecoration(
                                                color: Color(
                                                    0xFF4285F4),
                                                shape: BoxShape
                                                    .circle,
                                              ),
                                              child: const Text(
                                                  'G',
                                                  style: TextStyle(
                                                      fontSize:
                                                          13,
                                                      fontWeight:
                                                          FontWeight
                                                              .w800,
                                                      color: Colors
                                                          .white)),
                                            ),
                                            const SizedBox(
                                                width: 10),
                                            Flexible(
                                              child: Text(
                                                'Continue with Google',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                style: TextStyle(
                                                    fontSize: context
                                                        .font(14),
                                                    fontWeight:
                                                        FontWeight
                                                            .w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Terms pinned at bottom.
                    Padding(
                      padding: EdgeInsets.fromLTRB(context.padX,
                          context.rs(8), context.padX, context.rs(14)),
                      child: Center(
                        child: Text(
                          'By continuing, you agree to our Terms & Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: context.font(11),
                              color: OxroColors.muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }

  Widget _loginForm({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _submit(),
          decoration: _dec(
            hint: 'Enter email address',
            error: _emailError,
            prefix: const Icon(Icons.mail_outline,
                color: OxroColors.muted),
          ),
        ),
        SizedBox(height: context.rs(12)),
        OxroButton(label: 'Continue', onTap: _submit),
      ],
    );
  }

  Widget _signupForm({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameCtrl,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _submit(),
          decoration: _dec(
            hint: 'Full Name',
            error: _nameError,
            prefix: const Icon(Icons.person_outline,
                color: OxroColors.muted),
          ),
        ),
        SizedBox(height: context.rs(10)),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _submit(),
          decoration: _dec(
            hint: 'Enter email address',
            error: _emailError,
            prefix: const Icon(Icons.mail_outline,
                color: OxroColors.muted),
          ),
        ),
        SizedBox(height: context.rs(10)),
        TextField(
          controller: _referralCtrl,
          textCapitalization: TextCapitalization.characters,
          onSubmitted: (_) => _submit(),
          decoration: _dec(
            hint: 'Referral code (optional)',
            error: _referralError,
            prefix: const Icon(Icons.card_giftcard_outlined,
                color: OxroColors.muted),
          ),
        ),
        SizedBox(height: context.rs(12)),
        OxroButton(label: 'Create Account', onTap: _submit),
      ],
    );
  }
}
