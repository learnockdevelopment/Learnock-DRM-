import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:learnock_drm/widgets/premium_loader.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  bool _isLoading = false;
  bool _isInit = true;
  List<dynamic> _availableCourses = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);

    if (wp.isEagerLoaded && wp.cachedDashboard != null && wp.cachedFavorites != null) {
      _applyData(wp.cachedDashboard!, wp.cachedFavorites!);
      if (mounted) setState(() { _isLoading = false; _isInit = false; });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        wp.getDashboard(),
        wp.getFavorites(),
      ]);
      _applyData(results[0] as Map<String, dynamic>, results[1] as Map<String, dynamic>);
    } catch (_) {} finally {
      if (mounted) setState(() { _isLoading = false; _isInit = false; });
    }
  }

  void _applyData(Map<String, dynamic> dashRes, Map<String, dynamic> favRes) {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final List apiCourses = (dashRes['courses'] as List?) ?? [];
    final List allCoursesRaw = (dashRes['all_courses'] as List?) ?? json.decode(wp.activeWorkspace?.latestCoursesJson ?? '[]');
    
    final Set<int> enrolledIds = apiCourses.map((c) => int.tryParse(c['id']?.toString() ?? '0') ?? 0).toSet();
    final List favoritesList = (favRes['favorites'] as List?) ?? [];
    final Set<int> favoriteIds = favoritesList.map((f) => int.tryParse(f['id']?.toString() ?? '0') ?? 0).toSet();
    
    if (mounted) {
      setState(() {
        _availableCourses = allCoursesRaw.map((c) {
          final map = Map<String, dynamic>.from(c);
          final cid = int.tryParse(map['id']?.toString() ?? '0') ?? 0;
          map['is_favorite'] = favoriteIds.contains(cid);
          map['enrolled'] = enrolledIds.contains(cid);
          return map;
        }).where((c) {
          final cid = int.tryParse(c['id']?.toString() ?? '0') ?? 0;
          return !enrolledIds.contains(cid) && cid > 0;
        }).toList();
      });
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> course) async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
    if (cid == 0) return;

    setState(() => _isLoading = true);
    try {
      final bool wasFav = course['is_favorite'] == true || course['isFavorite'] == true;
      final bool isFav = !wasFav;
      
      setState(() {
        course['is_favorite'] = isFav;
        course['isFavorite'] = isFav;
      });
      
      await wp.toggleFavorite(cid);
      await _fetch();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                ),
                const SizedBox(height: 24),
                Text(lang.translate('success') ?? 'Success!', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 8),
                Text(isFav ? (lang.translate('added_to_favorites') ?? 'Added to favorites successfully.') : (lang.translate('removed_from_favorites') ?? 'Removed from favorites.'), textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () {
                      Navigator.pop(context);
                      _fetch();
                    },
                    child: Text(lang.translate('confirm') ?? 'OK', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.error_rounded, color: Colors.red, size: 48),
                ),
                const SizedBox(height: 24),
                Text(lang.translate('failure') ?? 'Error', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 8),
                Text(e.toString().replaceAll('Exception: ', ''), textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () => Navigator.pop(context),
                    child: Text(lang.translate('confirm') ?? 'OK', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final workspace = wp.activeWorkspace;
    final isRTL = lang.currentLocale.languageCode == 'ar';
    final List courses = _availableCourses;
    
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: Icon(isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, color: onSurface, size: 20), 
              onPressed: () => Navigator.pop(context)
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
              title: Text(
                lang.translate('all_courses') ?? 'Academy Curriculum', 
                style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [primaryColor.withOpacity(0.08), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          
          if (_isLoading && _isInit)
            const SliverFillRemaining(
              child: Center(
                child: PremiumLoader(),
              ),
            )
          else if (courses.isEmpty)
            SliverFillRemaining(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 100),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.file(
                        io.File('C:\\Users\\dell\\.gemini\\antigravity\\brain\\3609e548-4586-4257-aa07-8b9199d4f59a\\no_courses_mockup_1774986859239.png'), // HIGH-FIDELITY MOCKUP
                        width: 280,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (c,e,s) => Icon(Icons.auto_awesome_mosaic_rounded, size: 80, color: Theme.of(context).dividerColor),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      lang.translate('empty_courses_title') ?? 'Your journey starts here',
                      style: TextStyle(color: onSurface, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lang.translate('empty_courses_subtitle') ?? 'Explore our wide range of courses specifically designed for you.',
                      style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 13, height: 1.5, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCourseCard(courses[index], primaryColor, onSurface, context, lang),
                  childCount: courses.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, Color primary, Color onSurface, BuildContext context, LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor, width: 2),
        boxShadow: [BoxShadow(color: primary.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: InkWell(
        onTap: () {
          final e = course['enrolled'];
          final isEnrolled = e == true || e == 1 || e == '1' || e == 'true';
          final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
          if (!isEnrolled) {
            Navigator.pushNamed(context, '/subscribe', arguments: course);
            return;
          }
          if (cid > 0) Navigator.pushNamed(context, '/course', arguments: cid);
        },
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                children: [
                  Image.network(
                    course['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&q=80',
                    height: 180, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (c,e,s) => Container(height: 180, color: Theme.of(context).dividerColor, child: const Icon(Icons.school_rounded, size: 48)),
                  ),
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(100)),
                      child: Text("${course['price']} ${lang.translate('currency_le')}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ),
                  Positioned(
                     top: 12, left: 12,
                     child: InkWell(
                       onTap: _isLoading ? null : () => _toggleFavorite(course),
                       child: Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                         child: Icon((course['is_favorite'] == true || course['isFavorite'] == true) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: (course['is_favorite'] == true || course['isFavorite'] == true) ? Colors.red : Colors.grey, size: 20),
                       ),
                     ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (course['category'] != null && course['category'].toString().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(course['category'].toString().toUpperCase(), style: TextStyle(color: primary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(course['title'] ?? '', style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                  const SizedBox(height: 8),
                  Text(
                    course['description'] ?? '', 
                    style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 13, height: 1.5, fontWeight: FontWeight.bold)
                  ), // NO TRUNCATION
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (course['enrolled'] == true || course['enrolled'] == 1 || course['enrolled'] == '1' || course['enrolled'] == 'true') ...[
                        Icon(Icons.play_circle_fill_rounded, color: primary, size: 20),
                        const SizedBox(width: 8),
                        Text("${course['total_materials'] ?? 0} ${lang.translate('materials_count')}", style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w900)),
                      ],
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: (course['enrolled'] == true || course['enrolled'] == 1 || course['enrolled'] == '1' || course['enrolled'] == 'true') ? 8 : 6), 
                        decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]), 
                        child: Text(
                          ((course['enrolled'] == true || course['enrolled'] == 1 || course['enrolled'] == '1' || course['enrolled'] == 'true') ? (lang.translate('open_course') ?? 'START LEARNING') : (lang.translate('subscribe') ?? 'SUBSCRIBE')).toUpperCase(), 
                          style: TextStyle(color: Colors.white, fontSize: (course['enrolled'] == true || course['enrolled'] == 1 || course['enrolled'] == '1' || course['enrolled'] == 'true') ? 11 : 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                        )
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
