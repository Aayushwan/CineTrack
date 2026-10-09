// frontend/lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 👇 Added state variable to toggle password visibility
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF08080B),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showHero = constraints.maxWidth >= 900;

          return Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.85, -0.9),
                      radius: 1.15,
                      colors: [Color(0x332A0A42), Color(0xFF08080B)],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Row(
                  children: [
                    if (showHero) Expanded(flex: 11, child: _buildHeroPanel()),
                    Expanded(
                      flex: showHero ? 9 : 1,
                      child: _buildLoginPanel(context, authProvider, showHero),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroPanel() {
    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF27232E))),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17111E), Color(0xFF0F0C14), Color(0xFF08080B)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: _buildGlow(size: 360, color: const Color(0xFF9E3DDA)),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: _buildGlow(size: 420, color: const Color(0xFF5D1B89)),
          ),
          Positioned(top: 32, left: 40, child: _buildBrand()),
          Positioned(
            top: 34,
            right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF17151B),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF36313D)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 7, color: Color(0xFFBE4EFF)),
                  SizedBox(width: 8),
                  Text(
                    'MOVIES & TV, ORGANIZED',
                    style: TextStyle(
                      color: Color(0xFFC5C0CA),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 48, 48, 64),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TRACK. DISCOVER. REMEMBER.',
                      style: TextStyle(
                        color: Color(0xFFCA66FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Everything you watch,\n',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'all in one place.',
                            style: TextStyle(color: Color(0xFFC452FF)),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        height: 0.98,
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2.8,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Build your watchlist, rate your favorites, and discover '
                      'what to watch next with a community that loves stories '
                      'as much as you do.',
                      style: TextStyle(
                        color: Color(0xFFAAA5B1),
                        height: 1.7,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        _buildStat(value: '12K+', label: 'TITLES TO DISCOVER'),
                        Container(
                          width: 1,
                          height: 38,
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          color: const Color(0xFF3B3742),
                        ),
                        _buildStat(value: '4.9', label: 'MEMBER RATING'),
                      ],
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

  Widget _buildLoginPanel(
    BuildContext context,
    AuthProvider authProvider,
    bool showHero,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: showHero ? 48 : 24,
        vertical: 32,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height - 64,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!showHero) ...[
                  Align(alignment: Alignment.centerLeft, child: _buildBrand()),
                  const SizedBox(height: 48),
                ],
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xE615151B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2D2933)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 48,
                        offset: Offset(0, 24),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFBE4EFF),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x55BE4EFF),
                                    blurRadius: 8,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: SizedBox(width: 7, height: 7),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'CINETRACK ACCOUNT',
                              style: TextStyle(
                                color: Color(0xFFCA66FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.7,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Welcome back.',
                          style: TextStyle(
                            color: Color(0xFFFAF9FC),
                            fontSize: 38,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.7,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Sign in to continue tracking movies and shows you love.',
                          style: TextStyle(
                            color: Color(0xFF918B99),
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 28),

                        if (authProvider.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A1118),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF7D263D),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFFF647C),
                                  size: 19,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    authProvider.errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFFF8B9C),
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        const Text(
                          'Email address',
                          style: TextStyle(
                            color: Color(0xFFDAD6DF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: Color(0xFFF5F3F8),
                            fontSize: 13,
                          ),
                          cursorColor: const Color(0xFFBD4DFF),
                          decoration: _inputDecoration(
                            hintText: 'Enter your email address',
                            icon: Icons.email_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        const Text(
                          'Password',
                          style: TextStyle(
                            color: Color(0xFFDAD6DF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          // 👇 Bound to the state variable
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            color: Color(0xFFF5F3F8),
                            fontSize: 13,
                          ),
                          cursorColor: const Color(0xFFBD4DFF),
                          decoration: _inputDecoration(
                            hintText: 'Enter your password',
                            icon: Icons.lock_outline_rounded,
                            // 👇 Added the toggle icon button
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF77717D),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          height: 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: authProvider.isLoading
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF5E356D),
                                        Color(0xFF4B2C69),
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFFB143EB),
                                        Color(0xFF8431D9),
                                      ],
                                    ),
                              boxShadow: authProvider.isLoading
                                  ? null
                                  : const [
                                      BoxShadow(
                                        color: Color(0x557427A6),
                                        blurRadius: 24,
                                        offset: Offset(0, 12),
                                      ),
                                    ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: authProvider.isLoading
                                  ? null
                                  : _submit,
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      width: 21,
                                      height: 21,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Sign in',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Color(0x2FFFFFFF),
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(8),
                                            ),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'New to CineTrack? ',
                              style: TextStyle(
                                color: Color(0xFF817C87),
                                fontSize: 12,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/register'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFCA5FFF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Create an account',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '© 2026 CineTrack',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF55515A),
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 👇 Added optional suffixIcon parameter
  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF625D67), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF77717D), size: 20),
      suffixIcon: suffixIcon, // 👇 Assigned here
      filled: true,
      fillColor: const Color(0xFF0E0E12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF37323D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA943E9), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE34D67)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF647C), width: 1.4),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFF7388), fontSize: 11),
    );
  }

  Widget _buildBrand() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BrandMark(),
        SizedBox(width: 12),
        Text(
          'CineTrack',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildStat({required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF88828F),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildGlow({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCA53FF), Color(0xFF7C2BE8)],
        ),
        border: Border.all(color: const Color(0x55D9A8FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x447C2BE8),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.movie_filter_outlined,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
