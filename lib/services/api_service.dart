// services/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://k12.easylearn.org.in/Easylearn';

  // ===============================================
  // DEVICE ID HELPER
  // ===============================================

  // ── Persistent device ID (SharedPreferences — works on Web + Android + iOS) ──
  static String? _cachedDeviceId;

  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      String? stored = prefs.getString('el_device_id');
      if (stored != null && stored.isNotEmpty) {
        _cachedDeviceId = stored;
        return stored;
      }
      String newId;
      if (kIsWeb) {
        newId = 'web_device_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
      } else {
        try {
          final deviceInfo = DeviceInfoPlugin();
          if (Platform.isAndroid) {
            final androidInfo = await deviceInfo.androidInfo;
            newId = androidInfo.id;
          } else if (Platform.isIOS) {
            final iosInfo = await deviceInfo.iosInfo;
            newId = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
          } else {
            newId = 'device_${DateTime.now().millisecondsSinceEpoch}';
          }
        } catch (_) {
          newId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
        }
      }
      await prefs.setString('el_device_id', newId);
      _cachedDeviceId = newId;
      return newId;
    } catch (e) {
      print('Error getting device ID: $e');
      final fallback = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      _cachedDeviceId = fallback;
      return fallback;
    }
  }


  // ===============================================
  // LAST LOGIN SAVE / GET (for logout → auto re-login)
  // ===============================================

  /// Logout ke baad email+password yaad rahe
  static Future<void> saveLastLogin({
    required String email,
    required String password,
    required int grade,
    required List<String> mediums,
    String? partner,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_login_email',    email);
      await prefs.setString('last_login_password', password);
      await prefs.setInt   ('last_login_grade',    grade);
      await prefs.setStringList('last_login_mediums', mediums);
      if (partner != null) await prefs.setString('last_login_partner', partner);
      else await prefs.remove('last_login_partner');
      print('[saveLastLogin] saved → $email | grade $grade');
    } catch (e) {
      print('[saveLastLogin] error: $e');
    }
  }

  /// Saved last login data wapas lo
  static Future<Map<String, dynamic>?> getLastLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email    = prefs.getString('last_login_email');
      final password = prefs.getString('last_login_password');
      final grade    = prefs.getInt('last_login_grade');
      final mediums  = prefs.getStringList('last_login_mediums');
      final partner  = prefs.getString('last_login_partner');
      if (email == null || password == null || grade == null) return null;
      return {
        'email':    email,
        'password': password,
        'grade':    grade,
        'mediums':  mediums ?? ['English Medium'],
        'partner':  partner,
      };
    } catch (e) {
      print('[getLastLogin] error: $e');
      return null;
    }
  }

  /// Logout ke time clear karo
  static Future<void> clearLastLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_login_email');
      await prefs.remove('last_login_password');
      await prefs.remove('last_login_grade');
      await prefs.remove('last_login_mediums');
      await prefs.remove('last_login_partner');
    } catch (e) {
      print('[clearLastLogin] error: $e');
    }
  }

  // ===============================================
  // SIGNUP / LOGIN WITH PASSWORD
  // ===============================================

  /// Signup ya login ke liye OTP bhejo
  /// Returns: {'is_new': true/false} — new user hai ya existing
  static Future<Map<String, dynamic>?> signupSendOtp(String email, String sessionToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/signup_send_otp'),
        body: {'email': email, 'session_token': sessionToken},
      );
      print('signupSendOtp: ${response.statusCode} | ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') return data['data'];
      }
      return null;
    } catch (e) {
      print('signupSendOtp error: $e');
      return null;
    }
  }

  /// OTP verify ke baad password set karo
  static Future<bool> setPassword(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/set_password'),
        body: {'email': email, 'password': password},
      );
      print('setPassword: ${response.statusCode} | ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Response'] == 'OK';
      }
      return false;
    } catch (e) {
      print('setPassword error: $e');
      return false;
    }
  }

  /// Email + password se login karo
  /// Returns: user data map ya null on failure
  /// Special: returns {'error': 'NO_PASSWORD'} agar user ne password set nahi kiya
  static Future<Map<String, dynamic>?> loginWithPassword(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/login_with_password'),
        body: {'email': email, 'password': password},
      );
      print('loginWithPassword: ${response.statusCode} | ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') return data['data'];
        if (data['data'] == 'NO_PASSWORD') return {'error': 'NO_PASSWORD'};
      }
      return null;
    } catch (e) {
      print('loginWithPassword error: $e');
      return null;
    }
  }

  // ===============================================
  // TV LOGIN — QR + OTP METHODS
  // ===============================================

  /// TV App ke liye session token generate karo
  /// Backend: Course_Controller/generate_tv_session
  static Future<String?> generateTvSession() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/generate_tv_session'),
      );

      print('Generate TV Session Response: ${response.statusCode}');
      print('Generate TV Session Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          return data['token'];
        }
      }
      return null;
    } catch (e) {
      print('Generate TV session error: $e');
      return null;
    }
  }

  /// TV App polling — har 5 seconds mein check karo ki user login hua ya nahi
  /// Backend: Course_Controller/check_tv_login
  /// Returns: {'status': 'logged_in', 'mobile': '9876543210'} OR {'status': 'pending'}
  static Future<Map<String, dynamic>?> checkTvLoginStatus(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/check_tv_login'),
        body: {'token': token},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Check TV login status error: $e');
      return null;
    }
  }

  /// Email pe OTP bhejo
  /// Backend: Course_Controller/send_otp
  static Future<bool> sendOtp(String email, String sessionToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/send_otp'),
        body: {
          'email': email,
          'session_token': sessionToken,
        },
      );

      print('Send OTP Response: ${response.statusCode}');
      print('Send OTP Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Response'] == 'OK';
      }
      return false;
    } catch (e) {
      print('Send OTP error: $e');
      return false;
    }
  }

  /// OTP verify karo — sahi hone par TV session bhi update hoga
  /// Backend: Course_Controller/verify_otp
  static Future<bool> verifyOtp(
    String email,
    String otp,
    String sessionToken,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/verify_otp'),
        body: {
          'email': email,
          'otp': otp,
          'session_token': sessionToken,
        },
      );

      print('Verify OTP Response: ${response.statusCode}');
      print('Verify OTP Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Response'] == 'OK';
      }
      return false;
    } catch (e) {
      print('Verify OTP error: $e');
      return false;
    }
  }

  // ===============================================
  // PROFILE MANAGEMENT APIs
  // ===============================================

  /// Create new profile
  static Future<Map<String, dynamic>?> createProfile(
    Map<String, dynamic> profileData,
  ) async {
    try {
      final deviceId = await getDeviceId();

      // Body build karo — Gmail flow mein email alag se bhejo
      final Map<String, String> body = {
        'device_id': deviceId,
        'name':      profileData['name']   ?? '',
        'avatar':    profileData['avatar'] ?? '',
      };

      // email field — Gmail flow
      if (profileData['email'] != null && (profileData['email'] as String).isNotEmpty) {
        body['email'] = profileData['email'];
      }

      // mobile + pin_code — normal flow
      if (profileData['mobile'] != null && (profileData['mobile'] as String).isNotEmpty) {
        // Sirf tab bhejo agar valid 10-digit number hai (Gmail email nahi)
        final mobile = profileData['mobile'] as String;
        if (!mobile.contains('@')) {
          body['mobile']   = mobile;
          body['pin_code'] = profileData['pin_code'] ?? '';
        } else {
          // mobile field mein email aa gaya (purani code compatibility)
          body['email'] = mobile;
        }
      }

      if (profileData['pin_code'] != null && !body.containsKey('pin_code')) {
        body['pin_code'] = profileData['pin_code'];
      }

      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/create_profile'),
        body: body,
      );

      print('Create Profile Response: ${response.statusCode}');
      print('Create Profile Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Create profile error: $e');
      return null;
    }
  }

  /// Profile setup complete karo (grade, medium, partner, state)
  static Future<bool> completeProfileSetup({
    required String profileId,
    required int grade,
    required String medium,
    required String partner,
    required String state,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/complete_profile_setup'),
        body: {
          'profile_id': profileId,
          'grade': grade.toString(),
          'medium': medium,
          'partner': partner,
          'state': state,
        },
      );

      print('Complete Setup Response: ${response.statusCode}');
      print('Complete Setup Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Response'] == 'OK';
      }
      return false;
    } catch (e) {
      print('Complete profile setup error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REGISTER AND SETUP — Single-step API
  // Email/password el_app_users mein + el_user_profiles mein complete data
  // ek hi call mein save hoga (do-step flow ki jagah)
  //
  // Returns: profile map (el_user_profiles row) ya null on failure
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> registerAndSetup({
    required String email,
    required String password,
    required String name,
    required String avatar,
    required List<String> grades,   // e.g. ['6'] ya ['7','8']
    required String medium,         // 'Hindi' / 'English' / 'Odia'
    required String partner,        // e.g. 'Aarshi'
    required String state,          // e.g. 'Maharashtra'
  }) async {
    try {
      final deviceId = await getDeviceId();

      final primaryGrade = grades.isNotEmpty
          ? (grades.first == 'Nursery' ? '0' : grades.first)
          : '6';

      final gradesForApi = grades
          .map((g) => g == 'Nursery' ? '0' : g)
          .toList();

      final body = <String, String>{
        'device_id' : deviceId,
        'email'     : email,
        'password'  : password,
        'name'      : name,
        'avatar'    : avatar,
        'grade'     : primaryGrade,
        'grades'    : jsonEncode(gradesForApi),
        'medium'    : medium,
        'partner'   : partner,
        'state'     : state,
      };

      print('[registerAndSetup] Sending → email=$email grade=$primaryGrade medium=$medium partner=$partner state=$state device=$deviceId');

      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/register_and_setup'),
        body: body,
      );

      print('[registerAndSetup] status=${response.statusCode}');
      print('[registerAndSetup] body=${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          return data['data'] as Map<String, dynamic>?;
        }
        print('[registerAndSetup] ERROR: ${data['message']}');
      }
      return null;
    } catch (e) {
      print('[registerAndSetup] Exception: $e');
      return null;
    }
  }

  /// Device ke saare profiles fetch karo
  static Future<List<dynamic>> getAllProfiles() async {
    try {
      final deviceId = await getDeviceId();

      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/get_profiles'),
        body: {'device_id': deviceId},
      );

      print('Get Profiles Response: ${response.statusCode}');
      print('Get Profiles Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          return data['data'];
        }
      }
      return [];
    } catch (e) {
      print('Get profiles error: $e');
      return [];
    }
  }

  /// Profile ko active set karo
  static Future<bool> setActiveProfile(String profileId) async {
    try {
      final deviceId = await getDeviceId();

      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/set_active_profile'),
        body: {'profile_id': profileId, 'device_id': deviceId},
      );

      print('Set Active Profile Response: ${response.statusCode}');
      print('Set Active Profile Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Response'] == 'OK';
      }
      return false;
    } catch (e) {
      print('Set active profile error: $e');
      return false;
    }
  }

  /// Profile activity update karo
  static Future<bool> updateProfileActivity(String profileId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/update_profile_activity'),
        body: {'profile_id': profileId},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Update profile activity error: $e');
      return false;
    }
  }

  // ===============================================
  // MODIFIED EXISTING APIs WITH PROFILE SUPPORT
  // ===============================================

  /// Login user with optional profile support
  static Future<Map<String, dynamic>?> loginUser(
    int grade, [
    String? profileId,
  ]) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Register_Controller/login_user_mobile'),
        body: {
          'email': 'schoolstudent$grade@gmail.com',
          'password': '1',
          if (profileId != null) 'profile_id': profileId,
        },
      );

      print('Login Response: ${response.statusCode}');
      print('Login Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          if (profileId != null) {
            await updateProfileActivity(profileId);
          }
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  /// Enrolled courses by partner with optional profile support
  static Future<List<dynamic>> getEnrolledCoursesByPartner(
    String regId,
    String classroomId,
    String id,
    String? partnerName, {
    String? profileId,
  }) async {
    try {
      print('[API] getEnrolledCourses → partner=$partnerName  reg=$regId  class=$classroomId  id=$id');

      final response = await http.post(
        Uri.parse(
          '$baseUrl/Course_Controller/enrolledcourse_details_getdata_android',
        ),
        body: {
          'reg_id': regId,
          'classroom_id': classroomId,
          'id': id,
          if (profileId != null) 'profile_id': profileId,
        },
      );

      print('[API] enrolledcourse status=${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          // data['data'] kabhi kabhi String hoti hai ("No Data Found")
          final rawData = data['data'];
          if (rawData == null || rawData is! List) {
            print('[API] enrolledcourse → no list: $rawData');
            return [];
          }

          List<dynamic> courses = rawData;
          print('[API] enrolledcourse → ${courses.length} courses before filter');
          for (var c in courses) {
            print('[API]   id=${c["id"]}  name=${c["course_name"]}  partner=${c["partner_name"]}');
          }

          if (partnerName != null && partnerName.isNotEmpty) {
            final filtered = courses.where((c) {
              final cp = (c['partner_name']?.toString() ?? '').toLowerCase();
              return cp == partnerName.toLowerCase();
            }).toList();

            print('[API] partner filter "$partnerName" → ${filtered.length} courses');
            // Agar filter ke baad kuch nahi → sab return karo (partner mismatch ignore)
            if (filtered.isNotEmpty) courses = filtered;
          }

          return courses;
        }
      }
      return [];
    } catch (e) {
      print('[API] getEnrolledCourses error: $e');
      return [];
    }
  }

  // ===============================================
  // PROGRESS TRACKING APIs
  // ===============================================

  /// Content access track karo
  static Future<bool> trackContentAccess({
    required String profileId,
    required String courseId,
    required String courseName,
    required String subject,
    required String chapterId,
    required String chapterName,
    required String contentType, // 'video', 'book', 'quiz'
    required int timeSpent, // in minutes
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();

      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/track_content_access'),
        body: {
          'profile_id': profileId,
          'course_id': courseId,
          'course_name': courseName,
          'subject': subject,
          'chapter_id': chapterId,
          'chapter_name': chapterName,
          'content_type': contentType,
          'time_spent': timeSpent.toString(),
          'device_info': deviceInfo,
        },
      );

      print('Track Content Response: ${response.statusCode}');
      print('Track Content Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Response'] == 'OK';
      }
      return false;
    } catch (e) {
      print('Track content access error: $e');
      return false;
    }
  }

  /// Chapter completed mark karo
  static Future<bool> markChapterCompleted({
    required String profileId,
    required String courseId,
    required String chapterId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/mark_chapter_completed'),
        body: {
          'profile_id': profileId,
          'course_id': courseId,
          'chapter_id': chapterId,
        },
      );

      print('Mark Completed Response: ${response.statusCode}');
      print('Mark Completed Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Response'] == 'OK';
      }
      return false;
    } catch (e) {
      print('Mark chapter completed error: $e');
      return false;
    }
  }

  /// Course progress fetch karo
  static Future<Map<String, dynamic>?> getCourseProgress({
    required String profileId,
    required String courseId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/get_course_progress'),
        body: {'profile_id': profileId, 'course_id': courseId},
      );

      print('Get Progress Response: ${response.statusCode}');
      print('Get Progress Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Get course progress error: $e');
      return null;
    }
  }

  /// Profile ka saara progress fetch karo
  static Future<List<dynamic>> getAllProgress(String profileId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/get_course_progress'),
        body: {'profile_id': profileId},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          return data['data'] is List ? data['data'] : [data['data']];
        }
      }
      return [];
    } catch (e) {
      print('Get all progress error: $e');
      return [];
    }
  }

  /// Resume ke liye current position fetch karo
  static Future<Map<String, dynamic>?> getCurrentPosition(
    String profileId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/get_current_position'),
        body: {'profile_id': profileId},
      );

      print('Get Current Position Response: ${response.statusCode}');
      print('Get Current Position Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Get current position error: $e');
      return null;
    }
  }

  /// Profile learning stats fetch karo
  static Future<Map<String, dynamic>?> getProfileStats(String profileId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/get_profile_stats'),
        body: {'profile_id': profileId},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Get profile stats error: $e');
      return null;
    }
  }

  // ===============================================
  // EXISTING METHODS
  // ===============================================

  static Future<List<String>> getContentPartners() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Configuration_Controller/get_partner'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          List<String> partnerNames = [];
          for (var partner in data['data']) {
            if (partner['partner_name'] != null) {
              partnerNames.add(partner['partner_name'].toString());
            }
          }
          return partnerNames;
        }
      }
      return [];
    } catch (e) {
      print('Get partners error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getTopicsByCourseId(String courseId) async {
    try {
      print('[API] getTopicsByCourseId → course_id=$courseId');

      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/get_topics_by_course_id_android'),
        body: {'course_id': courseId},
      );

      print('[API] getTopics status=${response.statusCode}');
      final preview = response.body.length > 200 ? response.body.substring(0, 200) : response.body;
      print('[API] getTopics body=$preview');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          final list = data['data'];
          if (list is List) {
            print('[API] getTopics → ${list.length} topics');
            return list;
          }
        }
        print('[API] getTopics non-OK: ${data['Response']} ${data['message'] ?? ''}');
      }
      return [];
    } catch (e) {
      print('[API] getTopics error: $e');
      return [];
    }
  }


  static Future<String?> refreshVideoLinkByTopicId(
    String courseId,
    String topicId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/get_topics_by_course_id_android'),
        body: {'course_id': courseId},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK') {
          final topics = data['data'] as List<dynamic>;

          final topic = topics.firstWhere(
            (t) => t['id'].toString() == topicId.toString(),
            orElse: () => null,
          );

          if (topic != null && topic['video_links'] != null) {
            return topic['video_links'].toString();
          }
        }
      }
      return null;
    } catch (e) {
      print('Refresh video link error: $e');
      return null;
    }
  }

  // ===============================================
  // HELPER METHODS
  // ===============================================

  // ── AUTO-LOGIN ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> checkGmailLogin(String email) async {
    try {
      final deviceId = await getDeviceId();
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/check_gmail_login'),
        body: {'email': email, 'device_id': deviceId},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final resp = data['Response'] as String? ?? '';
        if (resp == 'OK') {
          final d = data['data'] as Map<String, dynamic>;
          return {
            'status':  'OK',
            'profile': d['profile'] as Map<String, dynamic>,
            'grades':  (d['grades']  as List<dynamic>).cast<String>(),
            'mediums': (d['mediums'] as List<dynamic>).cast<String>(),
            'partner': d['partner'] as String?,
          };
        } else if (resp == 'NEW_USER') {
          return {'status': 'NEW_USER', 'email': data['email'] ?? email};
        } else if (resp == 'SETUP_INCOMPLETE') {
          return {'status': 'SETUP_INCOMPLETE', 'data': data['data']};
        }
      }
      return null;
    } catch (e) {
      print('[Gmail] checkGmailLogin error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getActiveProfile() async {
    try {
      final deviceId = await getDeviceId();
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/get_active_profile'),
        body: {'device_id': deviceId},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'OK' && data['data'] != null) {
          final d = data['data'] as Map<String, dynamic>;
          return {
            'profile': d['profile'] as Map<String, dynamic>,
            'grades':  (d['grades']  as List<dynamic>).cast<String>(),
            'mediums': (d['mediums'] as List<dynamic>).cast<String>(),
            'partner': d['partner'] as String?,
          };
        }
      }
      return null;
    } catch (e) {
      print('[AutoLogin] getActiveProfile error: $e');
      return null;
    }
  }

  static Future<String> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release}, ${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion}, ${iosInfo.name} ${iosInfo.model}';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Device Info Error';
    }
  }

  // ===============================================
  // LIBRARY
  // ===============================================

  /// K12 school ki library books fetch karo
  /// Same reg_id + permissions use karo jo course mein use hota hai
  static Future<List<dynamic>> getLibraryBooks({
  required String regId,
  String permissions = 'School',
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/Dashboard_Controller/get_library_books_android'),
      body: {
        'reg_id': regId,
        'permissions': permissions,
      },
    );

    print('[Library] status=${response.statusCode}');
    print('[Library] body=${response.body}');

    if (response.statusCode == 200) {
      // HTML check karo — agar < se start ho toh PHP error hai
      if (response.body.trim().startsWith('<')) {
        print('[Library] PHP error/HTML response mila');
        return [];
      }
      
      final data = json.decode(response.body);
      if (data['Response'] == 'OK' && data['data'] is List) {
        return data['data'] as List<dynamic>;
      }
    }
    return [];
  } catch (e) {
    print('[Library] error: $e');
    return [];
  }
}

  // ===============================================
  // EXAM APIs
  // ===============================================

  /// Enrolled courses fetch karo (ExamListPage ke liye)
  static Future<List<dynamic>> getEnrolledCoursesForExam({
    required String id,
    required String classroomId,
    required String regId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Course_Controller/enrolledcourse_details_getdata'),
        body: {
          'id':           id,
          'classroom_id': classroomId,
          'reg_id':       regId,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final arr = data['data'];
        if (arr is List) return arr;
      }
      return [];
    } catch (e) {
      print('[API] getEnrolledCoursesForExam error: $e');
      return [];
    }
  }

  /// Exam list fetch karo (ExamListPage ke liye)
  static Future<List<dynamic>> getExamList({
    required String id,
    required String classroomId,
    required String regId,
    required String permissions,
    required String uniqueId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Exam_Controller/exam_list'),
        body: {
          'id':           id,
          'classroom_id': classroomId,
          'reg_id':       regId,
          'permissions':  permissions,
          'unique_id':    uniqueId,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as int? ?? 0;
        if (status == 200 && data['data'] is List) return data['data'];
      }
      return [];
    } catch (e) {
      print('[API] getExamList error: $e');
      return [];
    }
  }

  /// MCQ questions fetch karo (ExamDetailPage ke liye)
  /// MCQ questions fetch karo
  /// Endpoint: exam_question_student
  /// Params: exam_id (uniqueId), id (studentId), classroom_id
  static Future<List<dynamic>> getMcqQuestions({
    required String examId,
    required String studentId,
    required String classroomId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Exam_Controller/exam_question_student'),
        body: {
          'exam_id':      examId,       // unique_id string — "20260111234016"
          'id':           studentId,    // student id
          'classroom_id': classroomId,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as int? ?? 0;
        if (status == 200 && data['data'] is List) return data['data'];
      }
      return [];
    } catch (e) {
      print('[API] getMcqQuestions error: $e');
      return [];
    }
  }

  /// Har option select pe answer save karo (real-time)
  /// Endpoint: Exam_Controller/add_mcq_question_answer_final
  static Future<void> saveAnswer({
    required String examId,
    required String accountId,
    required String questionId,
    required String option,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/Exam_Controller/add_mcq_question_answer_final'),
        body: {
          'id':                examId,
          'account_id':        accountId,
          'option':            option,
          'question':          questionId,
          'multiple_response': '0',
        },
      );
      print('[API] saveAnswer → exam=$examId q=$questionId opt=$option');
    } catch (e) {
      print('[API] saveAnswer error: $e');
    }
  }

  /// Submit ke baad server se result fetch karo
  /// Endpoint: Exam_Controller/mcq_exam_question_answer
  static Future<List<dynamic>> getExamResult({
    required String studentId,
    required String examId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Exam_Controller/mcq_exam_question_answer'),
        body: {
          'id':      studentId,
          'exam_id': examId,
        },
      );
      if (response.statusCode == 200) {
        print('[API] getExamResult raw: \${response.body.substring(0, response.body.length.clamp(0, 600))}');
        final data = json.decode(response.body);
        if (data['status'] == 200 && data['data'] is List) {
          final list = data['data'] as List;
          if (list.isNotEmpty) {
            print('[API] getExamResult row[0] keys: \${(list[0] as Map).keys.toList()}');
            print('[API] getExamResult row[0]: \${list[0]}');
          }
          return list;
        }
      }
      return [];
    } catch (e) {
      print('[API] getExamResult error: $e');
      return [];
    }
  }
}