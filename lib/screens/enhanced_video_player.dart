import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:io';

// This widget handles video launch with bulletproof error handling
class BulletproofVideoLauncher extends StatefulWidget {
  final String url;
  final String title;

  const BulletproofVideoLauncher({
    Key? key,
    required this.url,
    required this.title,
  }) : super(key: key);

  @override
  _BulletproofVideoLauncherState createState() =>
      _BulletproofVideoLauncherState();
}

class _BulletproofVideoLauncherState extends State<BulletproofVideoLauncher> {
  bool _isLaunching = false;
  String? _errorMessage;
  bool _hasLaunched = false;

  @override
  void initState() {
    super.initState();
    // Immediately try to launch in browser
    _handleVideoLaunch();
  }

  Future<void> _handleVideoLaunch() async {
    setState(() {
      _isLaunching = true;
      _errorMessage = null;
    });

    try {
      // Launch in browser
      await _launchInBrowser();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to open video: $e';
        _isLaunching = false;
      });
    }
  }

  Future<void> _launchInBrowser() async {
    try {
      final uri = Uri.parse(widget.url);

      bool launched = await launchUrl(
        uri,
        // inAppWebView on mobile/TV, platformDefault on web
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
      );

      if (launched) {
        setState(() {
          _hasLaunched = true;
          _isLaunching = false;
        });

        // Show brief success message then navigate back to content options
        _showLaunchSuccessAndNavigateBack();
      } else {
        throw Exception('Could not launch browser');
      }
    } catch (e) {
      throw Exception('Browser launch failed: $e');
    }
  }

  void _showLaunchSuccessAndNavigateBack() async {
    // Show success dialog briefly
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1D23),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 16),
            Text(
              'Video opening...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Press back to return',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );

    // Wait 1.5 seconds then navigate back to content options page
    await Future.delayed(Duration(milliseconds: 1500));

    if (mounted) {
      // Close the dialog first
      Navigator.of(context).pop();

      // Navigate back to content options page
      _navigateBackToContentOptions();
    }
  }

  // Helper method to navigate back safely
  void _navigateBackToContentOptions() {
    // Simple approach: pop until we find a route that's not a dialog or video player
    int popCount = 0;
    Navigator.of(context).popUntil((route) {
      popCount++;
      // Stop at the route before this one (ContentOptionsPage)
      return popCount >= 2 || route.isFirst;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Handle back button press
      onWillPop: () async {
        if (_hasLaunched) {
          // If browser was launched, go back to content options instead of staying here
          _navigateBackToContentOptions();
          return false; // Prevent default back action
        }
        return true; // Allow normal back action
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
          // Custom back button behavior
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              if (_hasLaunched) {
                // Navigate back to content options
                _navigateBackToContentOptions();
              } else {
                // Normal back action
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Center(
          child: _isLaunching
              ? _buildLaunchingWidget()
              : _hasLaunched
              ? _buildLaunchedWidget()
              : _buildErrorWidget(),
        ),
      ),
    );
  }

  Widget _buildLaunchingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Colors.blue),
        ),
        SizedBox(height: 24),
        Text(
          'Opening video in browser...',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        SizedBox(height: 12),
        Text(
          'For the best compatibility',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildLaunchedWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.open_in_browser, color: Colors.green, size: 64),
        SizedBox(height: 24),
        Text(
          'Video opened successfully!',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        SizedBox(height: 12),
        Text(
          'You can return to the app anytime',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            _navigateBackToContentOptions();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: Text('Back to Content'),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 64),
          SizedBox(height: 24),
          Text(
            'Unable to Open Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _handleVideoLaunch,
                child: Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Smart Video Player that tries native first, then falls back to browser
class SmartVideoPlayer extends StatefulWidget {
  final String url;
  final String title;

  const SmartVideoPlayer({Key? key, required this.url, required this.title})
    : super(key: key);

  @override
  _SmartVideoPlayerState createState() => _SmartVideoPlayerState();
}

class _SmartVideoPlayerState extends State<SmartVideoPlayer> {
  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to safely determine the approach
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determineVideoPlayerStrategy();
    });
  }

  Future<void> _determineVideoPlayerStrategy() async {
    try {
      // Check if we should even attempt native player
      bool shouldTryNative = await _shouldTryNativePlayer();

      if (shouldTryNative) {
        // Try to navigate to native player with error handling
        _navigateToNativePlayer();
      } else {
        // Go straight to browser
        _navigateToBrowserPlayer();
      }
    } catch (e) {
      print('Strategy determination error: $e');
      // Fallback to browser
      _navigateToBrowserPlayer();
    }
  }

  Future<bool> _shouldTryNativePlayer() async {
    try {
      // Check if VdoCipher plugin is available
      bool hasVdoCipher = await _checkVdoCipherAvailability();
      if (!hasVdoCipher) {
        print('VdoCipher not available, using browser');
        return false;
      }

      // Check device compatibility
      if (Platform.isAndroid) {
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        final manufacturer = deviceInfo.manufacturer.toLowerCase();

        // Known problematic manufacturers - go straight to browser
        final problematicBrands = [
          'xiaomi',
          'redmi',
          'realme',
          'oppo',
          'vivo',
          'oneplus',
          'huawei',
          'honor',
          'tecno',
          'infinix',
          'itel',
        ];

        if (problematicBrands.any((brand) => manufacturer.contains(brand))) {
          print('Problematic device detected: $manufacturer, using browser');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Compatibility check error: $e');
      return false;
    }
  }

  Future<bool> _checkVdoCipherAvailability() async {
    try {
      // Try to check if VdoCipher classes are available
      const platform = MethodChannel('vdocipher_flutter');
      await platform.invokeMethod('isAvailable');
      return true;
    } catch (e) {
      print('VdoCipher check failed: $e');
      return false;
    }
  }

  void _navigateToNativePlayer() {
    // Use a try-catch around navigation to native player
    try {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              SafeNativePlayer(url: widget.url, title: widget.title),
        ),
      );
    } catch (e) {
      print('Native player navigation failed: $e');
      _navigateToBrowserPlayer();
    }
  }

  void _navigateToBrowserPlayer() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            BulletproofVideoLauncher(url: widget.url, title: widget.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
            SizedBox(height: 24),
            Text(
              'Preparing video player...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'Checking device compatibility',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// Safe wrapper around native VdoCipher player
class SafeNativePlayer extends StatefulWidget {
  final String url;
  final String title;

  const SafeNativePlayer({Key? key, required this.url, required this.title})
    : super(key: key);

  @override
  _SafeNativePlayerState createState() => _SafeNativePlayerState();
}

class _SafeNativePlayerState extends State<SafeNativePlayer> {
  bool _hasError = false;
  Timer? _failsafeTimer;

  @override
  void initState() {
    super.initState();

    // Set a failsafe timer - if native player doesn't load in 3 seconds, go to browser
    _failsafeTimer = Timer(Duration(seconds: 3), () {
      if (mounted && !_hasError) {
        print('Failsafe timer triggered, switching to browser');
        _switchToBrowser('Failsafe timeout');
      }
    });
  }

  void _switchToBrowser(String reason) {
    if (!mounted || _hasError) return;

    setState(() {
      _hasError = true;
    });

    print('Switching to browser: $reason');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            BulletproofVideoLauncher(url: widget.url, title: widget.title),
      ),
    );
  }

  @override
  void dispose() {
    _failsafeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(); // Empty container while transitioning
    }

    // Try to build the actual VdoCipher player
    try {
      // Import VdoCipher dynamically to avoid crashes
      return FutureBuilder(
        future: _buildVdoCipherPlayer(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _switchToBrowser('VdoCipher build error: ${snapshot.error}');
            });
            return Container();
          }

          if (snapshot.hasData) {
            _failsafeTimer?.cancel(); // Cancel failsafe if player loaded
            return snapshot.data as Widget;
          }

          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(widget.title),
            ),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Native player build error: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _switchToBrowser('Native player build failed: $e');
      });
      return Container();
    }
  }

  Future<Widget> _buildVdoCipherPlayer() async {
    // This is where you'd import and use your actual VdoCipher player
    // For now, return a placeholder that will trigger browser fallback
    await Future.delayed(Duration(seconds: 1));
    throw Exception(
      'VdoCipher not properly configured - using browser fallback',
    );
  }
}

// Main entry point - use this instead of your current video player
class VideoPlayerLauncher {
  static void launch(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmartVideoPlayer(url: url, title: title),
      ),
    );
  }
}