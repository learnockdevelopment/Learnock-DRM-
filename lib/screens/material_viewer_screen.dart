import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:google_fonts/google_fonts.dart' as modern_fonts;
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:learnock_drm/providers/theme_provider.dart';
import 'package:flutter_bunny_video_player/flutter_bunny_video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:learnock_drm/widgets/premium_loader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'package:flutter/services.dart';

import 'dart:async';

class MaterialViewerScreen extends StatefulWidget {
  final Map<String, dynamic> material;
  final int? courseId;
  final bool forceLandscape;
  final Map<String, dynamic>? nextMaterial;
  const MaterialViewerScreen({super.key, required this.material, this.courseId, this.forceLandscape = false, this.nextMaterial});

  @override
  State<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends State<MaterialViewerScreen> {
  bool _isLoading = true;
  String? _localPdfPath;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  String? _bunnyVideoId;
  String? _bunnyLibraryId;
  bool _isLandscapeMode = false;
  bool _showNextHint = false;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    NoScreenshot.instance.screenshotOff();
    
    _isLandscapeMode = widget.forceLandscape;
    if (_isLandscapeMode) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  void _videoListener() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    
    final duration = _videoPlayerController!.value.duration;
    final position = _videoPlayerController!.value.position;
    final remaining = duration - position;
    
    if (widget.nextMaterial != null && remaining.inSeconds <= 60 && remaining.inSeconds > 0) {
      if (!_showNextHint) {
        setState(() {
          _showNextHint = true;
        });
      }
      setState(() {
        _remainingSeconds = remaining.inSeconds;
      });
    } else if (_showNextHint && remaining.inSeconds > 60) {
      setState(() {
        _showNextHint = false;
      });
    }
  }

  Future<void> _fetch() async {
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      final material = widget.material;
      final type = material['type']?.toString().toLowerCase();
      
      // PURE DIRECT URL EXTRACTION
      final String directUrl = material['link_url']?.toString() ?? 
                               material['content_url']?.toString() ?? 
                               material['file_path']?.toString() ?? 
                               material['url']?.toString() ?? '';
      
      if (type == 'pdf' || type == 'document' || type == 'pdf_file') {
         if (directUrl.isNotEmpty && !directUrl.contains('<iframe')) {
           await _downloadPdf(directUrl);
         }
      } else {
         _initVideo(directUrl);
      }
      
      if (mounted) setState(() => _isLoading = false);

      // MARK PROGRESS
      final courseIdVal = widget.courseId ?? int.tryParse(material['course_id']?.toString() ?? '0') ?? 0;
      if (courseIdVal != 0) await wp.markProgress(courseIdVal, material);
      
    } catch (e) {
      debugPrint('Content Load Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _downloadPdf(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final dir = await getApplicationDocumentsDirectory();
      _localPdfPath = '${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(_localPdfPath!);
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('PDF Download Error: $e');
    }
  }

  void _initVideo(String url) {
    final material = widget.material;
    
    // BUNNY SDK BRIDGE (PREMIUM PLAYBACK)
    if (material['bunny_video_id'] != null || material['bunny_id'] != null) {
       setState(() {
         _bunnyVideoId = (material['bunny_video_id'] ?? material['bunny_id']).toString();
         _bunnyLibraryId = (material['bunny_library_id'] ?? material['library_id'] ?? '519048').toString();
       });
       return;
    }

    if (url.isNotEmpty) {
      String streamUrl = url;
      if (url.contains('<iframe')) {
        streamUrl = RegExp(r'src="([^"]+)"').firstMatch(url)?.group(1) ?? url;
      }
      
       _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
       _videoPlayerController!.addListener(_videoListener);
       _chewieController = ChewieController(
         videoPlayerController: _videoPlayerController!,
         autoPlay: true,
         looping: false,
         aspectRatio: 16 / 9,
         cupertinoProgressColors: ChewieProgressColors(playedColor: Theme.of(context).primaryColor, bufferedColor: Colors.white24, handleColor: Theme.of(context).primaryColor),
         materialProgressColors: ChewieProgressColors(playedColor: Theme.of(context).primaryColor, bufferedColor: Colors.white24, handleColor: Theme.of(context).primaryColor),
       );
    }
  }

  void _playNext() {
    if (widget.nextMaterial == null) return;
    
    // DISPOSE CURRENT PLAYER TO ENSURE NO SOUND OVERLAP
    _videoPlayerController?.removeListener(_videoListener);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    
    // FETCH THE UPDATED LIST TO FIND THE NEW "NEXT"
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final courseId = widget.courseId ?? int.tryParse(widget.material['course_id']?.toString() ?? '0') ?? 0;
    
    // RECURSIVE BINGE LEARNING TRANSITION
    Navigator.pushReplacementNamed(context, '/material', arguments: {
      'material': widget.nextMaterial, 
      'courseId': courseId,
      'forceLandscape': widget.nextMaterial!['type']?.toString().toLowerCase() == 'video' || widget.nextMaterial!['type']?.toString().toLowerCase() == 'mp4',
      'nextMaterial': null // The Dashboard or CourseDetail will figure out the next in real logic, but for simple transition we can pass it via previous state if available
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_videoListener);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    
    if (_isLandscapeMode) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final material = widget.material;
    final type = material['type']?.toString().toLowerCase();
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    
    final isRTL = lang.currentLocale.languageCode == 'ar';
    
    final isVideo = type != 'pdf' && type != 'document' && type != 'pdf_file';
    final isFullscreen = _isLandscapeMode || !isVideo; // PDFs are now fullscreen by default

    final Map<String, dynamic> materialData = widget.material;
    final contentUrl = materialData['content_url']?.toString() ?? materialData['link_url']?.toString() ?? materialData['file_path']?.toString() ?? materialData['url']?.toString() ?? '';

    return Scaffold(
      backgroundColor: isFullscreen ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
      appBar: isFullscreen ? null : AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(icon: Icon(isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, color: onSurface, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text(material['title'] ?? lang.translate('course_contents'), style: TextStyle(color: onSurface, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _isLoading 
                  ? const PremiumLoader()
                  : isVideo
                    ? Container(
                        margin: _isLandscapeMode ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.black, 
                          borderRadius: _isLandscapeMode ? null : BorderRadius.circular(28),
                          boxShadow: _isLandscapeMode ? [] : [
                            BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 40, spreadRadius: -10, offset: const Offset(0, 20)),
                            const BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 5)),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: (_bunnyVideoId != null)
                                ? BunnyPlayerView(
                                    videoId: _bunnyVideoId!, 
                                    libraryId: int.tryParse(_bunnyLibraryId ?? '0') ?? 0, 
                                    accessKey: material['video_access_key'] ?? material['access_key'] ?? "", 
                                    isPortrait: !_isLandscapeMode, 
                                    isScreenShotProtectEnable: true
                                  )
                                : (_chewieController != null) 
                                  ? Chewie(controller: _chewieController!) 
                                  : const PremiumLoader(),
                            ),
                            
                            // NEXT VIDEO OVERLAY (BINGE MODE)
                            if (_showNextHint && widget.nextMaterial != null)
                              Positioned(
                                top: _isLandscapeMode ? 32 : null,
                                bottom: _isLandscapeMode ? null : 40, 
                                right: isRTL ? null : 24,
                                left: isRTL ? 24 : null,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1.0),
                                  duration: const Duration(milliseconds: 600),
                                  builder: (context, opacity, child) => Opacity(
                                    opacity: opacity,
                                    child: Transform.translate(offset: Offset(0, (1 - opacity) * 10), child: child),
                                  ),
                                  child: GestureDetector(
                                    onTap: _playNext,
                                    child: Container(
                                      width: 280,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white24, width: 2),
                                        boxShadow: [
                                          BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 30, spreadRadius: -5),
                                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.network(
                                                  widget.nextMaterial!['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=200&q=80',
                                                  width: 72, height: 40, fit: BoxFit.cover,
                                                ),
                                              ),
                                              Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14)),
                                            ],
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text("NEXT LESSON IN ${_remainingSeconds}S", style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                                const SizedBox(height: 4),
                                                Text(widget.nextMaterial!['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            if (_isLandscapeMode)
                              Positioned(
                                top: 20, 
                                left: isRTL ? null : 20,
                                right: isRTL ? 20 : null,
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                  child: IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            // PREMIUM OVERLAY LABEL (TOP LEFT)
                            if (!_isLandscapeMode)
                              Positioned(
                                top: 16, left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.security_rounded, color: Colors.white, size: 10),
                                      const SizedBox(width: 6),
                                      Text('SECURE STREAM', style: modern_fonts.GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : (type == 'pdf' || type == 'document' || type == 'pdf_file')
                      ? Stack(
                          children: [
                            if (_localPdfPath != null)
                               PDFView(filePath: _localPdfPath!, autoSpacing: true, enableSwipe: true, pageSnap: true, swipeHorizontal: true, nightMode: true)
                            else
                               _buildPdfDownloadNotice(contentUrl, lang, primaryColor),
                            
                            // FLOATING CLOSE BUTTON FOR PDF
                            Positioned(
                                top: 20, 
                                right: isRTL ? null : 20,
                                left: isRTL ? 20 : null,
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                                  ),
                                ),
                            ),
                          ],
                        )
                      : _buildDefaultLessonNotice(material, lang),
              ),
            ),
            
            // LESSON DETAILS DRAWER
            if (!_isLoading && !isFullscreen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 2))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(lang.translate('now_active').toUpperCase(), style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                        const Spacer(),
                        Icon(Icons.shield_rounded, color: primaryColor.withOpacity(0.5), size: 16),
                        const SizedBox(width: 4),
                        Text('DRM PROTECTED', style: TextStyle(color: primaryColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(material['title'] ?? '', style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfDownloadNotice(String url, LanguageProvider lang, Color primary) {
     return Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         const PremiumLoader(),
         const SizedBox(height: 24),
         Text(lang.translate('loading_curriculum') ?? 'INITIALIZING CURRICULUM...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
       ],
     );
  }

  Widget _buildDefaultLessonNotice(Map<String, dynamic> material, LanguageProvider lang) {
     return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Theme.of(context).dividerColor, shape: BoxShape.circle), child: Icon(Icons.article_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), size: 56)),
          const SizedBox(height: 24),
          Text(material['title'] ?? '', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
     );
  }
}

