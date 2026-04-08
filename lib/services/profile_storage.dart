// services/profile_storage.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProfileStorage {
  // Storage keys
  static const String _activeProfileKey = 'active_profile_id';
  static const String _profilesListKey = 'cached_profiles_list';
  static const String _currentPositionKey = 'current_position_';
  static const String _progressCacheKey = 'progress_cache_';
  static const String _filtersKey = 'filters_'; // ✅ Added for filter tracking

  // ===============================================
  // PROFILE MANAGEMENT
  // ===============================================

  static Future<void> setActiveProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, profileId);
    print('Set active profile: $profileId');
  }

  static Future<String?> getActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileKey);
  }

  static Future<void> clearActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeProfileKey);
  }

  static Future<void> cacheProfiles(List<Map<String, dynamic>> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = json.encode(profiles);
    await prefs.setString(_profilesListKey, profilesJson);
    print('Cached ${profiles.length} profiles locally');
  }

  static Future<List<Map<String, dynamic>>> getCachedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_profilesListKey);

    if (profilesJson != null) {
      final profilesList = json.decode(profilesJson) as List;
      return profilesList.cast<Map<String, dynamic>>();
    }

    return [];
  }

  static Future<void> clearCachedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profilesListKey);
  }

  // ===============================================
  // FILTER MANAGEMENT (NEW)
  // ===============================================

  /// Save filters for a profile
  static Future<void> saveFilters(
    String profileId,
    Map<String, dynamic> filters,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("$_filtersKey$profileId", json.encode(filters));
    print("Saved filters for profile $profileId");
  }

  /// Get saved filters for a profile
  static Future<Map<String, dynamic>?> getFilters(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final filtersJson = prefs.getString("$_filtersKey$profileId");
    if (filtersJson != null) {
      return json.decode(filtersJson) as Map<String, dynamic>;
    }
    return null;
  }

  /// Check if a profile has saved filters
  static Future<bool> hasSavedFilters(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey("$_filtersKey$profileId");
  }

  /// Clear filters for a profile
  static Future<void> clearFilters(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("$_filtersKey$profileId");
  }

  // ===============================================
  // CURRENT POSITION TRACKING
  // ===============================================

  static Future<void> saveCurrentPosition({
    required String profileId,
    required String courseId,
    required String courseName,
    required String subject,
    required String chapterId,
    required String chapterName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final position = {
      'course_id': courseId,
      'course_name': courseName,
      'subject': subject,
      'chapter_id': chapterId,
      'chapter_name': chapterName,
      'saved_at': DateTime.now().toIso8601String(),
    };

    final positionJson = json.encode(position);
    await prefs.setString('$_currentPositionKey$profileId', positionJson);
    print('Saved current position for profile $profileId');
  }

  static Future<Map<String, dynamic>?> getCurrentPosition(
    String profileId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final positionJson = prefs.getString('$_currentPositionKey$profileId');

    if (positionJson != null) {
      return json.decode(positionJson) as Map<String, dynamic>;
    }

    return null;
  }

  static Future<void> clearCurrentPosition(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_currentPositionKey$profileId');
  }

  // ===============================================
  // PROGRESS CACHING
  // ===============================================

  static Future<void> cacheProgress({
    required String profileId,
    required String courseId,
    required Map<String, dynamic> progress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final progressJson = json.encode(progress);
    await prefs.setString(
      '$_progressCacheKey${profileId}_$courseId',
      progressJson,
    );
  }

  static Future<Map<String, dynamic>?> getCachedProgress({
    required String profileId,
    required String courseId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final progressJson = prefs.getString(
      '$_progressCacheKey${profileId}_$courseId',
    );

    if (progressJson != null) {
      return json.decode(progressJson) as Map<String, dynamic>;
    }

    return null;
  }

  static Future<void> clearProgressCache(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (String key in keys) {
      if (key.startsWith('$_progressCacheKey$profileId')) {
        await prefs.remove(key);
      }
    }
  }

  // ===============================================
  // OFFLINE TRACKING
  // ===============================================

  static Future<void> saveOfflineContentAccess({
    required String profileId,
    required String courseId,
    required String courseName,
    required String subject,
    required String chapterId,
    required String chapterName,
    required String contentType,
    required int timeSpent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    const offlineKey = 'offline_content_access';

    final existingJson = prefs.getString(offlineKey);
    List<dynamic> offlineData = [];

    if (existingJson != null) {
      offlineData = json.decode(existingJson) as List;
    }

    offlineData.add({
      'profile_id': profileId,
      'course_id': courseId,
      'course_name': courseName,
      'subject': subject,
      'chapter_id': chapterId,
      'chapter_name': chapterName,
      'content_type': contentType,
      'time_spent': timeSpent,
      'access_time': DateTime.now().toIso8601String(),
    });

    await prefs.setString(offlineKey, json.encode(offlineData));
    print('Saved offline content access: $contentType for $chapterName');
  }

  static Future<List<Map<String, dynamic>>> getOfflineContentAccess() async {
    final prefs = await SharedPreferences.getInstance();
    const offlineKey = 'offline_content_access';

    final offlineJson = prefs.getString(offlineKey);
    if (offlineJson != null) {
      final offlineData = json.decode(offlineJson) as List;
      return offlineData.cast<Map<String, dynamic>>();
    }

    return [];
  }

  static Future<void> clearOfflineContentAccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_content_access');
  }

  // ===============================================
  // UTILITY METHODS
  // ===============================================

  static Future<void> clearAllProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final profileKeys = keys
        .where(
          (key) =>
              key.startsWith(_activeProfileKey) ||
              key.startsWith(_profilesListKey) ||
              key.startsWith(_currentPositionKey) ||
              key.startsWith(_progressCacheKey) ||
              key.startsWith(_filtersKey) || // ✅ Clear filters too
              key == 'offline_content_access',
        )
        .toList();

    for (String key in profileKeys) {
      await prefs.remove(key);
    }

    print('Cleared all profile data');
  }

  static Future<Map<String, int>> getStorageInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    int profileCount = 0;
    int progressCount = 0;
    int offlineCount = 0;
    int filterCount = 0;

    for (String key in keys) {
      if (key.startsWith(_progressCacheKey)) progressCount++;
      if (key.startsWith(_currentPositionKey)) profileCount++;
      if (key.startsWith(_filtersKey)) filterCount++;
      if (key == 'offline_content_access') offlineCount++;
    }

    return {
      'cached_profiles': profileCount,
      'cached_progress': progressCount,
      'offline_records': offlineCount,
      'saved_filters': filterCount,
    };
  }

  static Future<bool> hasProfileData() async {
    final activeProfileId = await getActiveProfileId();
    final cachedProfiles = await getCachedProfiles();

    return activeProfileId != null && cachedProfiles.isNotEmpty;
  }

  static Future<Map<String, dynamic>?> getProfileById(String profileId) async {
    final cachedProfiles = await getCachedProfiles();

    try {
      return cachedProfiles.firstWhere(
        (profile) => profile['id'].toString() == profileId,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<void> updateProfileInCache(
    Map<String, dynamic> updatedProfile,
  ) async {
    final cachedProfiles = await getCachedProfiles();
    final profileId = updatedProfile['id'].toString();

    final index = cachedProfiles.indexWhere(
      (profile) => profile['id'].toString() == profileId,
    );

    if (index != -1) {
      cachedProfiles[index] = updatedProfile;
      await cacheProfiles(cachedProfiles);
      print('Updated profile in cache: $profileId');
    }
  }
}
