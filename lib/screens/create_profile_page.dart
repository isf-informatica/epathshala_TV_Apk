// screens/create_profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/profile_storage.dart';
import 'filter_page.dart';

class CreateProfilePage extends StatefulWidget {
  final Function(Map<String, dynamic>) onProfileCreated;
  final String? prefillMobile; // ← TV/OTP Login se mobile prefill hoga
  final String? prefillEmail;   // ← Gmail flow se email prefill hoga

  const CreateProfilePage({
    Key? key,
    required this.onProfileCreated,
    this.prefillMobile,
    this.prefillEmail,
  }) : super(key: key);

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  String selectedAvatar = '👦';
  bool isCreating = false;
  bool _isGmailFlow = false;    // ← Gmail se aaya to email/password hide

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> avatars = [
    '👦',
    '👧',
    '🧑',
    '👨',
    '👩',
    '🧒',
    '👶',
    '🧓',
    '👴',
    '👵',
    '🐱',
    '🐶',
    '🦄',
    '🌟',
    '⚡',
    '🔥',
  ];

  @override
  void initState() {
    super.initState();

    // Gmail flow detect karo
    if (widget.prefillEmail != null && widget.prefillEmail!.isNotEmpty) {
      _isGmailFlow = true;
    }

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isCreating = true;
    });

    try {
      final email    = _isGmailFlow
          ? (widget.prefillEmail ?? '')
          : _emailController.text.trim();
      final password = _isGmailFlow ? '' : _passwordController.text.trim();
      final name     = _nameController.text.trim();

      // ✅ FIX: create_profile (2-step) ki jagah seedha FilterPage pe jao
      // FilterPage → registerAndSetup → el_user_profiles mein sab ek saath save
      // (is tarah koi incomplete profile nahi banega)
      final profileData = <String, dynamic>{
        'email':    email,
        'password': password,
        'name':     name,
        'avatar':   selectedAvatar,
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FilterPage(profile: profileData),
        ),
      );

    } catch (e) {
      _showError(
        'An error occurred. Please check your connection and try again.',
      );
    } finally {
      setState(() {
        isCreating = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFDC2626).withOpacity(0.3),
                  ),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Error',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1A1D23),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF30363D), width: 1),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 12,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 360;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E13),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: Container(
                    margin: const EdgeInsets.only(left: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D23),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF21262D)),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    'Create Profile',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Form Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Gmail verified badge
                          if (_isGmailFlow) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A3A5C).withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.email_rounded, color: Color(0xFF60A5FA), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Gmail: ${widget.prefillEmail ?? ''}',
                                      style: const TextStyle(
                                        color: Color(0xFF60A5FA),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],



                          // Avatar Selection
                          _buildSection(
                            title: 'Choose Avatar',
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF1A1D23),
                                    Color(0xFF21262D),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF30363D),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Selected Avatar Preview
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: const RadialGradient(
                                        colors: [
                                          Color(0xFF4F46E5),
                                          Color(0xFF3B82F6),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF4F46E5,
                                          ).withOpacity(0.3),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        selectedAvatar,
                                        style: const TextStyle(fontSize: 36),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // Avatar Grid
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 8,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                        ),
                                    itemCount: avatars.length,
                                    itemBuilder: (context, index) {
                                      final avatar = avatars[index];
                                      final isSelected =
                                          avatar == selectedAvatar;
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedAvatar = avatar;
                                          });
                                          HapticFeedback.lightImpact();
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(
                                                    0xFF4F46E5,
                                                  ).withOpacity(0.2)
                                                : const Color(0xFF30363D),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF4F46E5)
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              avatar,
                                              style: const TextStyle(
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Name Input
                          _buildSection(
                            title: 'Student Name',
                            child: TextFormField(
                              controller: _nameController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter student name',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF1A1D23),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF30363D),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF30363D),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF4F46E5),
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDC2626),
                                    width: 2,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDC2626),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a name';
                                }
                                if (value.trim().length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Email + Password — Gmail flow mein hide karo
                          if (!_isGmailFlow) ...[
                          _buildSection(
                            title: 'Email',
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter email address',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFF8B949E),
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF1A1D23),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter email address';
                                }
                                final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Password Input
                          _buildSection(
                            title: 'Password',
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: !_passwordVisible,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter password (min 6 characters)',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Color(0xFF8B949E),
                                  size: 20,
                                ),
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(() => _passwordVisible = !_passwordVisible),
                                  child: Icon(
                                    _passwordVisible
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    color: const Color(0xFF8B949E),
                                    size: 20,
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF1A1D23),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.trim().length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ),

                          ], // end if (!_isGmailFlow)

                          const SizedBox(height: 40),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0E13), Color(0xFF1A1D23)],
          ),
          border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isCreating ? null : _createProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF21262D),
                disabledForegroundColor: const Color(0xFF8B949E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: isCreating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Create Profile & Set Preferences',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}