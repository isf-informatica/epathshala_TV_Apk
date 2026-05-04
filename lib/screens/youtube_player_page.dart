import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// YouTube Player — No WebView, No RAM issue
/// Uses youtube_explode_dart to extract stream URL → video_player (ExoPlayer) se play
///
/// FOLDER: D:\epathshala_TV_Apk\lib\screens\youtube_player_page.dart
///
/// Usage:
/// ```dart
/// import 'youtube_player_page.dart';
///
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => YouTubePlayerPage(url: videoUrl, title: title),
/// ));
/// ```

class YouTubePlayerPage extends StatefulWidget {
  final String url;   // YouTube URL (embed / watch / youtu.be)
  final String title;

  const YouTubePlayerPage({
    Key? key,
    required this.url,
    required this.title,
  }) : super(key: key);

  @override
  State<YouTubePlayerPage> createState() => _YouTubePlayerPageState();
}

class _YouTubePlayerPageState extends State<YouTubePlayerPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';
  bool _showControls = true;

  // ─── Extract video ID from any YouTube URL ───────────────────────────────
  String? _extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // 🔥 Case 1: youtube.com/watch?v=
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }

    // 🔥 Case 2: youtu.be/
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }

    // 🔥 Case 3: embed / shorts
    for (final segment in uri.pathSegments) {
      if (segment.length == 11) return segment;
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    final videoId = _extractVideoId(widget.url);
    if (videoId == null) {
      setState(() {
        _loading = false;
        _error = true;
        if (videoId == null) {
          Navigator.pop(context); // fallback
          return;
        }
      });
      return;
    }

    try {
      final yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(videoId);

      final streams = manifest.muxed.sortByVideoQuality();
      if (streams.isEmpty) {
        yt.close();
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = 'No playable stream found.\nVideo restricted ho sakta hai.';
        });
        return;
      }

      // 720p prefer, nahi toh highest available
      StreamInfo streamInfo = streams.last;
      for (final s in streams) {
        if (s.videoQuality == VideoQuality.high720) {
          streamInfo = s;
          break;
        }
      }

      final streamUrl = streamInfo.url.toString();
      yt.close();

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      await _controller!.initialize();
      _controller!.play();
      _controller!.setLooping(false);

      if (mounted) setState(() => _loading = false);
      _autoHideControls();

    } catch (e) {
      debugPrint('[YouTubePlayer] Error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = e.toString().contains('Sign in') || e.toString().contains('age')
              ? 'Video age-restricted hai — play nahi ho sakta'
              : e.toString().contains('network') || e.toString().contains('Socket')
              ? 'Network error — internet check karo'
              : 'Video load failed.\n${e.toString().substring(0, e.toString().length.clamp(0, 120))}';
        });
      }
    }
  }

  void _autoHideControls() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showControls) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _autoHideControls();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
    });
  }

  void _seekForward() {
    if (_controller == null) return;
    _controller!.seekTo(_controller!.value.position + const Duration(seconds: 10));
    setState(() => _showControls = true);
    _autoHideControls();
  }

  void _seekBackward() {
    if (_controller == null) return;
    final pos = _controller!.value.position - const Duration(seconds: 10);
    _controller!.seekTo(pos < Duration.zero ? Duration.zero : pos);
    setState(() => _showControls = true);
    _autoHideControls();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;

          if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          if (_controller == null || _loading) return KeyEventResult.ignored;

          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.gameButtonA) {
            _togglePlayPause();
            _toggleControls();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) { _seekForward(); return KeyEventResult.handled; }
          if (key == LogicalKeyboardKey.arrowLeft)  { _seekBackward(); return KeyEventResult.handled; }
          if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
            setState(() => _showControls = true);
            _autoHideControls();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [

              // ── Video / Loading / Error ──────────────────────────────────
              if (_loading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFFF0000), strokeWidth: 3),
                      SizedBox(height: 20),
                      Text('Video load ho raha hai...', style: TextStyle(color: Colors.white70, fontSize: 18)),
                      SizedBox(height: 8),
                      Text('YouTube se stream extract ho rahi hai', style: TextStyle(color: Colors.white38, fontSize: 14)),
                    ],
                  ),
                )
              else if (_error)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 64),
                        const SizedBox(height: 20),
                        Text(_errorMsg, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Wapas Jao'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF0000),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_controller != null && _controller!.value.isInitialized)
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),

              // ── Controls overlay ─────────────────────────────────────────
              if (!_loading && !_error && _showControls && _controller != null)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
                        stops: [0.0, 0.25, 0.75, 1.0],
                      ),
                    ),
                    child: Column(
                      children: [
                        // Top bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Play/Pause + Seek
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10, color: Colors.white, size: 46),
                              onPressed: _seekBackward,
                            ),
                            const SizedBox(width: 28),
                            GestureDetector(
                              onTap: _togglePlayPause,
                              child: Container(
                                width: 72, height: 72,
                                decoration: const BoxDecoration(color: Color(0xFFFF0000), shape: BoxShape.circle),
                                child: ValueListenableBuilder(
                                  valueListenable: _controller!,
                                  builder: (_, val, __) => Icon(
                                    val.isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white, size: 44,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 28),
                            IconButton(
                              icon: const Icon(Icons.forward_10, color: Colors.white, size: 46),
                              onPressed: _seekForward,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Progress bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          child: ValueListenableBuilder(
                            valueListenable: _controller!,
                            builder: (_, value, __) {
                              final pos = value.position;
                              final dur = value.duration;
                              final progress = dur.inMilliseconds > 0
                                  ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                                  : 0.0;
                              return Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFFFF0000),
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: const Color(0xFFFF0000),
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                      trackHeight: 4,
                                      overlayColor: Colors.red.withOpacity(0.2),
                                    ),
                                    child: Slider(
                                      value: progress,
                                      onChanged: (v) {
                                        _controller!.seekTo(Duration(milliseconds: (v * dur.inMilliseconds).round()));
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatDuration(pos), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                        Text(_formatDuration(dur), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}