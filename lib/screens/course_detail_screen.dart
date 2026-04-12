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
  bool _isSubscribing = false;
  String _activeFilter = "ALL";

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

  // ─── SUBSCRIBE: Wallet checkout ────────────────────────────────────────────
  Future<void> _handleWalletCheckout() async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final sm = ScaffoldMessenger.of(context);
    if (_isSubscribing) return;
    setState(() => _isSubscribing = true);
    try {
      final res = await wp.checkoutWallet(widget.courseId);
      sm.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Enrolled successfully!'), backgroundColor: Colors.green));
      await wp.eagerLoad();
      if (mounted) await _fetch(); // Reload course to reflect enrollment
    } catch (e) {
      final msg = e.toString().contains('already subscribed') || e.toString().contains('مشترك')
          ? 'You are already enrolled!'
          : e.toString();
      sm.showSnackBar(SnackBar(content: Text(msg), backgroundColor: e.toString().contains('already') ? Colors.orange : Colors.red));
      if (e.toString().contains('already subscribed') || e.toString().contains('مشترك')) {
        await wp.eagerLoad();
        if (mounted) await _fetch();
      }
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  // ─── SUBSCRIBE: Coupon code ─────────────────────────────────────────────────
  void _showCouponSheet(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final primaryColor = Theme.of(context).primaryColor;
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(sheetCtx).viewInsets.bottom + 40),
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lang.translate('redeem_coupon') ?? 'Activate Coupon',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Text(lang.translate('coupon_hint') ?? 'Enter your coupon code',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX-XXXX',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.qr_code_rounded, color: primaryColor),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (controller.text.isEmpty) return;
                  final nav = Navigator.of(sheetCtx);
                  final sm = ScaffoldMessenger.of(context);
                  nav.pop();
                  setState(() => _isSubscribing = true);
                  try {
                    final res = await wp.redeemCoupon(controller.text);
                    sm.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Success!'), backgroundColor: Colors.green));
                    await wp.eagerLoad();
                    if (mounted) await _fetch();
                  } catch (e) {
                    sm.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                  } finally {
                    if (mounted) setState(() => _isSubscribing = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(lang.translate('confirm') ?? 'Confirm',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MATERIAL ROW ──────────────────────────────────────────────────────────
  Widget _buildMaterialItem(
    Map<String, dynamic> material,
    int index,
    List allMaterials,
    bool isEnrolled,
    LanguageProvider lang,
    Color primaryColor,
    Color onSurface,
  ) {
    final type = material['type']?.toString().toLowerCase() ?? 'lesson';
    final isCompleted = material['isCompleted'] ?? false;

    // ACCESS: free OR enrolled
    final isFree = material['is_free'] == 1 || material['is_free'] == true || material['is_free'] == '1';
    final hasAccess = isEnrolled || isFree;

    // FILTER
    if (_activeFilter == "VIDEOS" && (type != 'video' && type != 'mp4')) return const SizedBox();
    if (_activeFilter == "FILES" && (type != 'pdf_file' && type != 'pdf' && type != 'document' && type != 'file')) return const SizedBox();

    final bool isVideo = type == 'video' || type == 'mp4';

    return Column(
      children: [
        InkWell(
          onTap: hasAccess
              ? () {
                  final nextMaterial = (index + 1 < allMaterials.length) ? allMaterials[index + 1] : null;
                  Navigator.pushNamed(context, '/material', arguments: {
                    'material': material,
                    'courseId': widget.courseId,
                    'forceLandscape': isVideo,
                    'nextMaterial': nextMaterial,
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // THUMBNAIL / ICON
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 64,
                      decoration: BoxDecoration(
                        color: hasAccess ? onSurface.withOpacity(0.05) : onSurface.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: material['thumbnail_url'] != null
                            ? Image.network(
                                material['thumbnail_url'],
                                width: 100, height: 64, fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => _typeIcon(type, hasAccess, primaryColor),
                              )
                            : _typeIcon(type, hasAccess, primaryColor),
                      ),
                    ),
                    if (isVideo && hasAccess)
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white30, width: 1)),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                      ),
                    if (!hasAccess)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                        child: Icon(Icons.lock_rounded, color: primaryColor, size: 16),
                      ),
                    if (isCompleted && hasAccess)
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${index + 1}. ${material['title'] ?? ''}",
                        style: TextStyle(
                          color: hasAccess
                              ? (isCompleted ? onSurface.withOpacity(0.5) : onSurface)
                              : onSurface.withOpacity(0.3),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (isFree && !isEnrolled) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                              child: const Text("FREE", style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            isVideo ? Icons.play_circle_outline_rounded : Icons.description_outlined,
                            color: onSurface.withOpacity(0.3), size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            type.toUpperCase(),
                            style: TextStyle(color: onSurface.withOpacity(0.35), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!hasAccess)
                  Icon(Icons.lock_outline_rounded, color: onSurface.withOpacity(0.15), size: 18),
              ],
            ),
          ),
        ),
        Divider(color: onSurface.withOpacity(0.08), height: 1),
      ],
    );
  }

  Widget _typeIcon(String type, bool hasAccess, Color primary) {
    final isVideo = type == 'video' || type == 'mp4';
    return Center(
      child: Icon(
        isVideo ? Icons.play_circle_outline_rounded : Icons.description_outlined,
        color: hasAccess ? primary.withOpacity(0.4) : primary.withOpacity(0.15),
        size: 28,
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dynamic courseObj = _courseData?['data']?['course'] ?? _courseData?['course'];
    final Map<String, dynamic>? course = courseObj is Map<String, dynamic> ? courseObj : null;

    final lang = Provider.of<LanguageProvider>(context);
    final wp = Provider.of<WorkspaceProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // ── THEME-AWARE COLOR TOKENS ──────────────────────────────────────────────
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = Theme.of(context).cardColor;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B);
    final textMuted = isDark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.4);
    final overlayLight = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
    final overlayMid = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
    final divider = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
    // ─────────────────────────────────────────────────────────────────────────

    final materials = (course?['materials'] as List?) ?? [];

    // ENROLLMENT / ACCESS
    final dynamic enrolledRaw = course?['isEnrolled'] ?? course?['is_enrolled'] ?? course?['is_accessible'];
    final bool isEnrolled = enrolledRaw == true || enrolledRaw == 1 || enrolledRaw == '1' || enrolledRaw == 'true';

    // CATEGORY
    String catStr = (course?['category_path'] ?? course?['category_depth'] ?? "").toString();
    if (catStr.isEmpty && course != null) {
      for (var c in [course['category_name'], course['category'], course['subject'], course['cat_name']]) {
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

    final isFavorited = wp.localFavoriteIds.contains(widget.courseId);

    if (_isLoading) return Scaffold(backgroundColor: scaffoldBg, body: const Center(child: PremiumLoader()));
    if (course == null) return Scaffold(backgroundColor: scaffoldBg, body: Center(child: Text(lang.translate('failure'), style: TextStyle(color: textSecondary))));

    // CONTINUE BUTTON LOGIC
    final lastAccessed = wp.lastAccessedMaterials[widget.courseId];
    final freeMaterials = materials.where((m) => m['is_free'] == 1 || m['is_free'] == true).toList();
    final accessibleMaterials = isEnrolled ? materials : freeMaterials;
    final Map<String, dynamic> targetMaterial = lastAccessed ??
        (accessibleMaterials.isNotEmpty ? accessibleMaterials[0] : (materials.isNotEmpty ? materials[0] : {}));
    final int targetIndex = materials.indexWhere((m) => (m['id']) == (targetMaterial['id']));
    final nextMat = (targetIndex != -1 && targetIndex + 1 < materials.length) ? materials[targetIndex + 1] : null;

    // COUNT
    final int freeMaterialsCount = materials.where((m) => m['is_free'] == 1 || m['is_free'] == true).length;

    return Scaffold(
      backgroundColor: scaffoldBg,
      // ── SUBSCRIBE BOTTOM BAR (only when not enrolled) ──
      bottomNavigationBar: !isEnrolled
          ? _buildSubscribeBar(course, lang, primaryColor, context)
          : null,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // HERO IMAGE
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 12 / 9,
                      child: Image.network(
                        course['image_url'] ?? course['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=800&q=80',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(color: Colors.white.withOpacity(0.05)),
                      ),
                    ),
                    // Gradient overlay for text readability
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                          ),
                        ),
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

                    // ENROLLMENT STATUS BADGE
                    if (isEnrolled)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.verified_rounded, color: Colors.green, size: 12),
                          const SizedBox(width: 6),
                          Text(lang.translate('joined') ?? 'ENROLLED', style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        ]),
                      ),

                    // CATEGORY BADGE + PRICE
                    Row(children: [
                      if (catStr.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: primaryColor.withOpacity(0.2))),
                          child: Text(catStr.toUpperCase(), style: TextStyle(color: primaryColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (!isEnrolled) Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.withOpacity(0.25))),
                        child: Text('${course['price'] ?? '0'} ${lang.translate('currency_le') ?? 'LE'}', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // TITLE
                    Text(course['title'] ?? '', style: TextStyle(color: textPrimary, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.2)),
                    const SizedBox(height: 16),

                    // STATS ROW — real data
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: overlayLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: overlayMid)),
                      child: Row(children: [
                        _buildStat(Icons.play_lesson_rounded, '${materials.length}', lang.translate('materials') ?? 'Lessons', primaryColor, textPrimary, textMuted),
                        _buildStatDivider(overlayMid),
                        _buildStat(Icons.people_rounded,
                          (() { final m = course['members_count'] ?? course['students_count'] ?? course['members'] ?? 0; return m.toString(); })(),
                          lang.translate('members') ?? 'Students', primaryColor, textPrimary, textMuted),
                        _buildStatDivider(overlayMid),
                        _buildStat(
                          isEnrolled ? Icons.lock_open_rounded : Icons.lock_rounded,
                          isEnrolled ? (lang.translate('active') ?? 'Active') : ('${freeMaterialsCount} ${lang.translate('materials') ?? ''}'),
                          isEnrolled ? lang.translate('now_active') ?? 'Access' : 'Free Preview',
                          isEnrolled ? Colors.green : Colors.orange,
                          textPrimary,
                          textMuted,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // CONTINUE / START BUTTON
                    if (isEnrolled || freeMaterialsCount > 0) ...[
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
                              'nextMaterial': nextMat,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.all(20),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(lastAccessed == null ? Icons.bolt_rounded : Icons.play_circle_filled_rounded, size: 26),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEnrolled
                                          ? (lastAccessed == null ? lang.translate('open_course')?.toUpperCase() ?? "START LEARNING" : "RESUME CURRICULUM")
                                          : "START FREE PREVIEW",
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.5),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(targetMaterial['title'] ?? 'First lesson', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // PROGRESS (enrolled only)
                    if (isEnrolled) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(lang.translate('progress')?.toUpperCase() ?? "COURSE PROGRESS", style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              Text("${wp.lastAccessedMaterials[widget.courseId] != null ? '40' : '0'}%", style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 5,
                            decoration: BoxDecoration(color: onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: wp.lastAccessedMaterials[widget.courseId] != null ? 0.4 : 0.02,
                              child: Container(decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(3))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // DESCRIPTION — only shown when no learning_outcomes (avoid duplication)
                    if ((course['description'] ?? '').toString().trim().isNotEmpty &&
                        (course['learning_outcomes'] ?? '').toString().trim().isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: overlayLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: overlayMid),
                        ),
                        child: Text(_stripHtml(course['description'] ?? ''),
                          style: TextStyle(color: textSecondary, fontSize: 14, height: 1.7, fontWeight: FontWeight.w400),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // WHAT YOU'LL LEARN (learning_outcomes)
                    if ((course['learning_outcomes'] ?? '').toString().trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryColor.withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.lightbulb_outline_rounded, color: primaryColor, size: 16),
                              const SizedBox(width: 8),
                              Text(lang.translate('what_youll_learn') ?? "WHAT YOU'LL LEARN", style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                            ]),
                            const SizedBox(height: 12),
                            Text(_stripHtml(course['learning_outcomes'] ?? ''),
                              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],


                    // INSTRUCTOR CARD
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: overlayLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: overlayMid)),
                      child: Row(children: [
                        CircleAvatar(radius: 20, backgroundColor: primaryColor.withOpacity(0.15), child: Icon(Icons.person_rounded, color: primaryColor, size: 20)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(course['teacher_name'] ?? 'Academy Expert', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                            Text(lang.translate('academy') ?? 'Instructor', style: TextStyle(color: textMuted, fontSize: 11)),
                          ],
                        )),
                        Icon(Icons.verified_rounded, color: primaryColor.withOpacity(0.6), size: 16),
                      ]),
                    ),
                    const SizedBox(height: 28),

                    // FAVORITES TOGGLE — optimistic UI
                    InkWell(
                      onTap: () async {
                        final newFav = !isFavorited;
                        
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Row(children: [
                            Icon(newFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 10),
                            Text(newFav ? (lang.translate('added_to_favorites') ?? 'Added to favorites') : (lang.translate('removed_from_favorites') ?? 'Removed from favorites')),
                          ]),
                          backgroundColor: newFav ? Colors.green.shade700 : Colors.grey.shade700,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        ));

                        try {
                          await wp.toggleFavoriteOptimistic(widget.courseId);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            ));
                          }
                          debugPrint('Fav Toggle Error: $e');
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _buildQuickAction(
                          isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          isFavorited ? (lang.translate('remove_favorites') ?? 'REMOVE FROM FAVORITES').toUpperCase() : (lang.translate('save_favorites') ?? 'SAVE IN FAVORITES').toUpperCase(),
                          isFavorited ? primaryColor : onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // CURRICULUM HEADER
                    Text(lang.translate('curriculum')?.toUpperCase() ?? "ACADEMY CURRICULUM", style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(height: 16),

                    // FILTER PILLS
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: overlayLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: overlayMid)),
                      child: Row(
                        children: [
                          Expanded(child: _buildFilterItem(lang.translate('all')?.toUpperCase() ?? "ALL")),
                          Expanded(child: _buildFilterItem(lang.translate('videos')?.toUpperCase() ?? "VIDEOS")),
                          Expanded(child: _buildFilterItem(lang.translate('files')?.toUpperCase() ?? "FILES")),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),

              // MATERIALS LIST
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildMaterialItem(
                      materials[index], index, materials, isEnrolled, lang, primaryColor, onSurface,
                    ),
                    childCount: materials.length,
                  ),
                ),
              ),

              // ENROLLED: UNENROLL BUTTON
              if (isEnrolled)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
                    child: InkWell(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                            title: Text(lang.translate('unenroll') ?? "UNENROLL FROM COURSE", style: TextStyle(color: onSurface, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                            content: Text(lang.translate('unenroll_hint') ?? "Your learning progress will be saved, but you will lose instant access until you re-subscribe.", style: TextStyle(color: textSecondary, fontSize: 12, height: 1.5)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(lang.translate('cancel')?.toUpperCase() ?? "CANCEL", style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900))),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: Text(lang.translate('unenroll')?.toUpperCase() ?? "UNENROLL", style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await wp.unenroll(widget.courseId);
                            await wp.eagerLoad();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('unenrolled_success') ?? "Unenrolled successfully"), backgroundColor: Colors.orange));
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
                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent.withOpacity(0.1))),
                        child: Row(
                          children: [
                            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 16),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(lang.translate('stop_learning')?.toUpperCase() ?? 'STOP LEARNING', style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w900)),
                              Text(lang.translate('unenroll_from_course') ?? 'Unenroll from this course', style: TextStyle(color: Colors.redAccent.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w600)),
                            ]),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.redAccent, size: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 180)),
            ],
          ),

          // SUBSCRIBE LOADING OVERLAY
          if (_isSubscribing)
            Container(
              color: Colors.black54,
              child: Center(child: SpinKitFadingCircle(color: primaryColor, size: 50)),
            ),
        ],
      ),
    );
  }

  // ─── SUBSCRIBE BOTTOM BAR ─────────────────────────────────────────────────
  Widget _buildSubscribeBar(Map<String, dynamic> course, LanguageProvider lang, Color primaryColor, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1)),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, -10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // PRICE ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((lang.translate('course_price') ?? 'COURSE PRICE').toUpperCase(),
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text("${course['price'] ?? '0.00'} ${lang.translate('currency_le') ?? 'LE'}",
                    style: TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.w900)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.lock_clock_rounded, color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Text((lang.translate('subscribe_to_unlock') ?? 'Subscribe to unlock').toUpperCase(),
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // WALLET BUTTON
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _handleWalletCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wallet_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(lang.translate('redeem_wallet') ?? 'Subscribe using Wallet',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // COUPON BUTTON
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => _showCouponSheet(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.confirmation_num_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(lang.translate('apply_coupon') ?? 'Coupon Code',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                ],
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
          label, textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.3),
            fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1,
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, color: iconColor ?? onSurface, size: 20),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildStat(IconData icon, String value, String label, Color accent, Color textPrimary, Color textMuted) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildStatDivider(Color color) {
    return Container(width: 1, height: 40, color: color);
  }

  // Strip HTML tags and decode common entities for clean plain text
  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    String result = html
        .replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return result;
  }
}

