import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:learnock_drm/providers/theme_provider.dart';
import 'package:learnock_drm/widgets/premium_loader.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Map<String, dynamic>? _courseData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      _courseData = await wp.getCourse(widget.courseId);
    } catch (e) {
      if (e.toString().contains('Session expired') || e.toString().contains('unauthorized')) {
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _activeFilter = "ALL";

  Widget _buildMaterialItem(Map<String, dynamic> material, int index, List allMaterials, LanguageProvider lang, Color primaryColor, Color onSurface) {
    final type = material['type']?.toString().toLowerCase() ?? 'lesson';
    final duration = material['duration'] ?? '15m';
    final description = material['description'] ?? 'Detailed lesson content and educational objectives.';
    final isCompleted = material['isCompleted'] ?? false;
    
    // FILTER LOGIC
    if (_activeFilter == "VIDEOS" && (type != 'video' && type != 'mp4')) return const SizedBox();
    if (_activeFilter == "FILES" && (type != 'pdf_file' && type != 'pdf' && type != 'document' && type != 'file')) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            final nextMaterial = (index + 1 < allMaterials.length) ? allMaterials[index + 1] : null;
            Navigator.pushNamed(context, '/material', arguments: {
              'material': material, 
              'courseId': widget.courseId,
              'forceLandscape': type == 'video' || type == 'mp4',
              'nextMaterial': nextMaterial
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          material['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&q=80',
                          width: 120,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (c,e,s) => Container(width: 120, height: 68, color: Colors.white.withOpacity(0.05)),
                        ),
                      ),
                    ),
                    if (type == 'video' || type == 'mp4')
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white38, width: 1)),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                      ),
                    if (isCompleted)
                      Positioned(
                        bottom: 4, right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.white, size: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${index + 1}. ${material['title'] ?? ''}",
                        style: TextStyle(color: isCompleted ? Colors.white60 : Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(type == 'video' || type == 'mp4' ? Icons.play_circle_outline_rounded : Icons.description_outlined, color: Colors.white30, size: 12),
                          const SizedBox(width: 6),
                          Text(
                            "$duration • ${type.toUpperCase()}",
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: HtmlWidget(
            description,
            textStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, height: 1.6, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dynamic courseObj = _courseData?['data']?['course'] ?? _courseData?['course'];
    final Map<String, dynamic>? course = courseObj is Map<String, dynamic> ? courseObj : null;
    
    final lang = Provider.of<LanguageProvider>(context);
    final wp = Provider.of<WorkspaceProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final materials = (course?['materials'] as List?) ?? [];

    // ROBUST CATEGORY DETECTION (PRIORITIZE STRINGS OVER IDS)
    String catStr = "";
    if (course != null) {
      final catCandidates = [course['category_name'], course['category'], course['subject'], course['cat_name']];
      for (var c in catCandidates) {
        if (c == null) continue;
        if (c is Map) {
          final n = (c['name'] ?? c['title'] ?? "").toString().trim();
          if (n.isNotEmpty) { catStr = n; break; }
        } else {
          final s = c.toString().trim();
          if (s.isNotEmpty && int.tryParse(s) == null) { catStr = s; break; }
        }
      }
    }

    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF000000), body: Center(child: PremiumLoader()));
    if (course == null) return Scaffold(backgroundColor: const Color(0xFF000000), body: Center(child: Text(lang.translate('failure'), style: const TextStyle(color: Colors.white24))));

    // CONTINUE LEARNING LOGIC
    final lastAccessed = wp.lastAccessedMaterials[widget.courseId];
    final Map<String, dynamic> targetMaterial = lastAccessed ?? (materials.isNotEmpty ? materials[0] : {});
    
    // FIND NEXT FOR CONTINUE BUTTON
    final int targetIndex = materials.indexWhere((m) => (m['id'] ?? m['id_material']) == (targetMaterial['id'] ?? targetMaterial['id_material']));
    final nextMat = (targetIndex != -1 && targetIndex + 1 < materials.length) ? materials[targetIndex + 1] : null;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 12 / 9,
                  child: Image.network(
                    course['image_url'] ?? course['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=800&q=80',
                    fit: BoxFit.cover,
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(),
                        Container(
                          decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white12)),
                          child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 10),
                if (catStr.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: primaryColor.withOpacity(0.2))),
                        child: Text(catStr.toUpperCase(), style: TextStyle(color: primaryColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  course['title'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text("2026 EDITION", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(width: 16),
                    Text("${materials.length} MODULES", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const Spacer(),
                    _buildMetaTag("4K"),
                    const SizedBox(width: 8),
                    _buildMetaTag("HDR"),
                  ],
                ),
                const SizedBox(height: 32),
                
                // PREMIUM CONTINUE BUTTON
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 30, spreadRadius: -10)],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                       final type = targetMaterial['type']?.toString().toLowerCase() ?? 'lesson';
                       Navigator.pushNamed(context, '/material', arguments: {
                          'material': targetMaterial, 
                          'courseId': widget.courseId,
                          'forceLandscape': type == 'video' || type == 'mp4',
                          'nextMaterial': nextMat
                       });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.all(20),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(lastAccessed == null ? Icons.bolt_rounded : Icons.play_circle_filled_rounded, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lastAccessed == null ? "START JOURNEY" : "RESUME CURRICULUM", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                              const SizedBox(height: 4),
                              Text(targetMaterial['title'] ?? 'The first lesson', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // PROGRESS BAR
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("COURSE PROGRESS", style: TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        Text("${(wp.lastAccessedMaterials[widget.courseId] != null) ? '40' : '0'}%", style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (wp.lastAccessedMaterials[widget.courseId] != null) ? 0.4 : 0.05,
                        child: Container(decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                HtmlWidget(
                  course['description'] ?? 'Expand your technical expertise with our world-class academy instructors.',
                  textStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.6, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    CircleAvatar(radius: 14, backgroundColor: Colors.white10, child: Icon(Icons.person_outline_rounded, color: Colors.white54, size: 14)),
                    const SizedBox(width: 12),
                    Text(
                      "Instructor: ${course['teacher_name'] ?? 'Academy Expert'}",
                      style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                InkWell(
                  onTap: () async {
                     try {
                        final res = await wp.toggleFavorite(widget.courseId);
                        setState(() {
                           if (courseObj is Map<String, dynamic>) {
                              courseObj['is_favorited'] = !(courseObj['is_favorited'] ?? false);
                           }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(course?['is_favorited'] == true ? "Saved to Favorites" : "Removed from Favorites"),
                          behavior: SnackBarBehavior.floating,
                          width: 250,
                          backgroundColor: Colors.white,
                        ));
                     } catch (e) {
                        debugPrint('Fav Toggle Error: $e');
                     }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _buildQuickAction(
                      (course?['is_favorited'] ?? false) ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                      (course?['is_favorited'] ?? false) ? "REMOVED FROM FAVORITES" : "SAVE IN FAVORITES",
                      (course?['is_favorited'] ?? false) ? primaryColor : Colors.white
                    ),
                  ),
                ),
                const SizedBox(height: 56),

                // SECTION HEADER
                Text("ACADEMY CURRICULUM", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 24),

                // GLASSMORPHIC FILTER
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                  child: Row(
                    children: [
                      Expanded(child: _buildFilterItem("ALL")),
                      Expanded(child: _buildFilterItem("VIDEOS")),
                      Expanded(child: _buildFilterItem("FILES")),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildMaterialItem(materials[index], index, materials, lang, primaryColor, onSurface),
                childCount: materials.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
              child: InkWell(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1A1A),
                      title: const Text("UNENROLL FROM COURSE", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      content: const Text("Your learning progress will be saved, but you will lose instant access until you re-subscribe.", style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900))),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true), 
                          child: const Text("UNENROLL", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      await wp.unenroll(widget.courseId);
                      await wp.eagerLoad(); // Refresh local cache
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unenrolled successfully"), backgroundColor: Colors.orange));
                        Navigator.pushReplacementNamed(context, '/dashboard');
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                    }
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("STOP LEARNING", style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w900)),
                          Text("Unenroll from this course", style: TextStyle(color: Colors.redAccent.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.redAccent, size: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterItem(String label) {
    final isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 10)] : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.3),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white10)),
      child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, [Color? iconColor]) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? Colors.white, size: 20),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ],
    );
  }
}

