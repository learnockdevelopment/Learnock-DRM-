import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:learnock_drm/providers/theme_provider.dart';
import 'package:learnock_drm/widgets/premium_loader.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

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

  Widget _buildMaterialItem(Map<String, dynamic> material, int index, LanguageProvider lang) {
    final isCompleted = material['isCompleted'] ?? false;
    final type = material['type'] ?? 'file';
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor, width: 2),
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/material', arguments: {'material': material, 'courseId': widget.courseId}),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: type == 'video' ? primaryColor.withOpacity(0.1) : Theme.of(context).dividerColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == 'video' ? Icons.play_arrow_rounded : Icons.description_outlined,
                  color: type == 'video' ? primaryColor : onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material['title'] ?? '',
                      style: TextStyle(
                        color: isCompleted ? onSurface.withOpacity(0.4) : onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type == 'video' ? lang.translate('video_lesson') : lang.translate('pdf_file'),
                      style: TextStyle(color: onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isCompleted)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
              else
                Icon(Icons.arrow_forward_ios_rounded, color: onSurfaceVariant.withOpacity(0.3), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dynamic courseObj = _courseData?['data']?['course'] ?? _courseData?['course'];
    final Map<String, dynamic>? course = courseObj is Map<String, dynamic> ? courseObj : null;
    
    final lang = Provider.of<LanguageProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? Center(child: PremiumLoader())
          : (course == null)
              ? Center(child: Text(lang.translate('failure'), style: const TextStyle(color: Color(0xFF94A3B8))))
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 200,
                      pinned: true,
                      elevation: 0,
                      backgroundColor: primaryColor,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          course['title'] ?? lang.translate('course_contents'),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              course['image_url'] ?? course['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=800&q=80',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(color: Colors.black26),
                            ),
                            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))),
                            
                            // FLOATING ACADEMY LOGO OVER COVER (REVERSE OF BACK BUTTON)
                            if (Provider.of<WorkspaceProvider>(context).activeWorkspace?.logoUrl != null)
                              PositionedDirectional(
                                top: 40,
                                end: 20, // OPPOSITE OF LEADING BACK BUTTON
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)]),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Image.network(Provider.of<WorkspaceProvider>(context).activeWorkspace!.logoUrl!, fit: BoxFit.contain, errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: primaryColor)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lang.translate('course_lessons'), style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            Text(
                              lang.translate('lessons_count').replaceAll('{}', ((course['materials'] as List?)?.length ?? 0).toString()),
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildMaterialItem(course['materials'][index], index, lang),
                          childCount: (course['materials'] as List).length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
    );
  }
}
