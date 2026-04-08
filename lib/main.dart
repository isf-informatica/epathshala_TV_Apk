// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';           // ← ADDED: MethodChannel ke liye
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'screens/grades_page.dart';
import 'screens/filter_page.dart';
import 'screens/subjects_page.dart';
import 'screens/profile_selection_page.dart';
import 'screens/create_profile_page.dart';
import 'screens/signup_page.dart';
import 'screens/login_page.dart';
import 'services/api_service.dart';
import 'services/profile_storage.dart';

// ─── AthenaStar Intent Channel ───────────────────────────────────
// AthenaStar OTT se launch hone pe yahan se data milega
const _intentChannel = MethodChannel('com.example.sabot_education/intent');

Future<Map<String, String>> _getAthenaSatarIntentData() async {
  try {
    final data = await _intentChannel.invokeMapMethod<String, String>('getIntentData');
    return data ?? {};
  } catch (_) {
    return {};
  }
}
// ─────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // WebView platform — webview_flutter_web auto-handles web
  // Android/TV pe separate entrypoint ya module se handle hoga

  // ── AthenaStar se launch hua? Check karo ──────────────────────
  final intentData = await _getAthenaSatarIntentData();
  final bool launchedFromAthenaStar = intentData['source'] == 'athenastar';
  // (Future use: intentData['screen'], intentData['courseId'] etc.)
  // ─────────────────────────────────────────────────────────────

  runApp(MyApp(launchedFromAthenaStar: launchedFromAthenaStar));
}

class MyApp extends StatelessWidget {
  final bool launchedFromAthenaStar; // ← ADDED

  const MyApp({Key? key, this.launchedFromAthenaStar = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Education Platform',
      theme: ThemeData(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AppEntryPoint(launchedFromAthenaStar: launchedFromAthenaStar), // ← UPDATED
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppEntryPoint extends StatefulWidget {
  final bool launchedFromAthenaStar; // ← ADDED

  const AppEntryPoint({Key? key, this.launchedFromAthenaStar = false}) : super(key: key);

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  final _googleSignIn = GoogleSignIn(scopes: ['email']);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(milliseconds: 600));

    // ── AthenaStar se launch hua → directly GradesPage skip login ──
    // (Optional: Agar SSO chahiye ho baad mein yahan token validate kar sakte ho)
    if (widget.launchedFromAthenaStar) {
      print('[Start] 🚀 Launched from AthenaStar OTT → skipping auth flow');
      // Abhi ke liye: local cache check karo, agar profile hai toh GradesPage
      // Warna normal signup flow
      await _localCacheFallback();
      return;
    }

    // ── Fresh install detection ────────────────────────────────────
    // Agar pehli baar app open ho raha hai (fresh install/reinstall),
    // local cache clear karo taaki purana data ghost na bane
    final prefs = await SharedPreferences.getInstance();
    final bool isFirstRun = !(prefs.getBool('app_installed') ?? false);
    if (isFirstRun) {
      print('[Start] 🆕 Fresh install detected → clearing cache');
      await ProfileStorage.cacheProfiles([]);
      await ProfileStorage.setActiveProfile('');
      await prefs.setBool('app_installed', true);
      print('[Start] Cache cleared → going to Signup');
      _goSignup();
      return;
    }

    // ══════════════════════════════════════════════════════════════
    // STEP 1: Device ka Gmail silently check karo (no dialog shown)
    // ══════════════════════════════════════════════════════════════
    String? gmailEmail;
    try {
      final googleUser = await _googleSignIn.signInSilently();
      gmailEmail = googleUser?.email;
      print('[Start] Gmail on device: ${gmailEmail ?? "NONE"}');
    } catch (e) {
      print('[Start] Gmail check error: $e');
    }

    // ══════════════════════════════════════════════════════════════
    // STEP 2: Gmail mila → el_app_users + el_user_profiles check
    //         Backend: check_gmail_login(email, device_id)
    //         Response: OK → GradesPage
    //                   SETUP_INCOMPLETE → FilterPage
    //                   NEW_USER → CreateProfilePage (email pre-fill)
    // ══════════════════════════════════════════════════════════════
    if (gmailEmail != null) {
      try {
        final result = await ApiService.checkGmailLogin(gmailEmail);

        if (result != null) {
          final status = result['status'] as String;

          if (status == 'OK') {
            // ✅ el_app_users mein email mili + el_user_profiles complete
            print('[Start] ✅ Gmail login OK → GradesPage');
            final profile = result['profile'] as Map<String, dynamic>;
            final grades  = result['grades']  as List<String>;
            final mediums = result['mediums']  as List<String>;
            final partner = result['partner']  as String?;

            await ProfileStorage.cacheProfiles([profile]);
            await ProfileStorage.setActiveProfile(profile['id'].toString());
            await ProfileStorage.saveFilters(profile['id'].toString(), {
              'selectedGrades':  grades,
              'selectedMediums': mediums.map((m) => m.replaceAll(' Medium', '')).toList(),
              'selectedPartner': partner,
            });

            _goGrades(profile: profile, grades: grades, mediums: mediums, partner: partner);
            return;

          } else if (status == 'SETUP_INCOMPLETE') {
            // el_app_users mein hai but CreateProfilePage nahi gaya tha
            // → CreateProfilePage pe bhejo (email pre-fill)
            print('[Start] Setup incomplete → CreateProfilePage');
            _goCreateProfile(gmailEmail);
            return;

          } else {
            // NEW_USER → el_app_users mein bhi nahi → CreateProfilePage
            print('[Start] New Gmail user → CreateProfilePage');
            _goCreateProfile(gmailEmail);
            return;
          }
        }
        // result null = network error → device_id fallback neeche
        print('[Start] Network error on checkGmailLogin → device_id fallback');
      } catch (e) {
        print('[Start] checkGmailLogin error: $e → device_id fallback');
      }
    }

    // ══════════════════════════════════════════════════════════════
    // STEP 3: Gmail nahi mila ya network fail → device_id se check
    // (Reinstall ke baad bhi kaam karta hai agar Gmail nahi hai)
    // ══════════════════════════════════════════════════════════════
    try {
      final backendResult = await ApiService.getActiveProfile();
      if (backendResult != null) {
        final profile = backendResult['profile'] as Map<String, dynamic>;
        final grades  = backendResult['grades']  as List<String>;
        final mediums = backendResult['mediums']  as List<String>;
        final partner = backendResult['partner']  as String?;

        await ProfileStorage.cacheProfiles([profile]);
        await ProfileStorage.setActiveProfile(profile['id'].toString());
        await ProfileStorage.saveFilters(profile['id'].toString(), {
          'selectedGrades':  grades,
          'selectedMediums': mediums.map((m) => m.replaceAll(' Medium', '')).toList(),
          'selectedPartner': partner,
        });

        print('[Start] device_id login → GradesPage');
        _goGrades(profile: profile, grades: grades, mediums: mediums, partner: partner);
        return;
      }
    } catch (e) {
      print('[Start] device_id check error: $e');
    }

    // ══════════════════════════════════════════════════════════════
    // STEP 4: Completely offline → local cache fallback
    // ══════════════════════════════════════════════════════════════
    await _localCacheFallback();
  }

  // ── Offline fallback ─────────────────────────────────────────
  Future<void> _localCacheFallback() async {
    try {
      final profiles = await ProfileStorage.getCachedProfiles();
      if (profiles.isEmpty) { _goSignup(); return; }

      final activeId = await ProfileStorage.getActiveProfileId();
      Map<String, dynamic>? profile;

      if (activeId != null) {
        try {
          profile = profiles.firstWhere(
            (p) => p['id'].toString() == activeId && _setupDone(p),
          );
        } catch (_) {}
      }
      profile ??= () {
        try { return profiles.firstWhere((p) => _setupDone(p)); }
        catch (_) { return null; }
      }();

      if (profile == null) { _goSignup(); return; }

      final pid     = profile['id'].toString();
      final filters = await ProfileStorage.getFilters(pid);
      List<String> grades  = (filters?['selectedGrades']  as List?)?.cast<String>() ?? [];
      List<String> mediums = (filters?['selectedMediums'] as List?)?.cast<String>() ?? [];
      String?      partner =  filters?['selectedPartner'] as String?;

      if (grades.isEmpty  && profile['grade']  != null) grades  = [profile['grade'].toString()];
      if (mediums.isEmpty && profile['medium'] != null) mediums = [profile['medium'].toString()];
      if (grades.isEmpty)  grades  = ['6','7','8','9','10','11','12'];
      if (mediums.isEmpty) mediums = ['English'];
      mediums = mediums.map((m) => m.contains('Medium') ? m : '$m Medium').toList();

      print('[Start] Offline cache → GradesPage');
      _goGrades(profile: profile, grades: grades, mediums: mediums, partner: partner);
    } catch (e) {
      print('[Start] Cache fallback error: $e');
      _goSignup();
    }
  }

  bool _setupDone(Map p) =>
      p['has_completed_setup'] == 1 ||
      p['has_completed_setup'] == '1' ||
      p['has_completed_setup'] == true;

  // ── Navigation ───────────────────────────────────────────────

  void _goGrades({
    required Map<String, dynamic> profile,
    required List<String> grades,
    required List<String> mediums,
    String? partner,
  }) async {
    // ✅ Agar sirf ek grade selected hai → directly SubjectsPage pe jao
    if (grades.length == 1) {
      final int gradeNum = int.tryParse(grades.first) ?? 6;

      // Mediums ko "X Medium" format mein fix karo
      final List<String> formattedMediums = mediums
          .map((m) => m.contains('Medium') ? m : '$m Medium')
          .toList();

      try {
        final loginResponse = await ApiService.loginUser(gradeNum);
        if (loginResponse != null && mounted) {
          final courses = await ApiService.getEnrolledCoursesByPartner(
            loginResponse['reg_id'],
            loginResponse['classroom_id'],
            loginResponse['id'],
            partner,
          );

          // Saare mediums ke liye ek list banao
          final List<Map<String, dynamic>> allMediumCourses = formattedMediums.map((m) {
            return {'medium': m, 'courses': courses};
          }).toList();

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => SubjectsPage(
                grade: gradeNum,
                medium: formattedMediums.first,
                courses: courses.cast<dynamic>(),
                loginData: loginResponse,
                allMediumCourses: allMediumCourses,
              ),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
          return;
        }
      } catch (e) {
        print('[_goGrades] Single grade auto-navigate error: $e');
        // Error pe GradesPage pe fallback karo
      }
    }

    // Multiple grades ya error → normal GradesPage
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => GradesPage(
          selectedProfile: profile,
          filteredGrades: grades,
          selectedMediums: mediums,
          selectedCategory: null,
          selectedPartner: partner,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _goFilter(Map<String, dynamic> profile) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => FilterPage(profile: profile)),
    );
  }

  /// Naya Gmail user → directly CreateProfilePage (email pre-filled)
  void _goCreateProfile(String email) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CreateProfilePage(
          prefillEmail: email,   // ← Gmail email — mobile nahi
          onProfileCreated: (_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => ProfileSelectionPage()),
            );
          },
        ),
      ),
    );
  }

  /// Show LoginPage first — user can sign up from there
  void _goSignup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(
          onLoginComplete: (email, password) {
            // ✅ FIX: CreateProfilePage ki jagah seedha FilterPage pe jao
            // email + password milega → registerAndSetup → el_user_profiles mein sab data
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => FilterPage(
                  profile: {
                    'email':    email,
                    'password': password,
                    'name':     '',
                    'avatar':   '????',
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Splash Screen ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E13),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            const Text(
              'Education for all',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}