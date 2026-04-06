import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:learnock_drm/providers/theme_provider.dart';
import 'package:learnock_drm/widgets/premium_loader.dart';
import 'package:learnock_drm/models/workspace.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _lastWorkspaceId;
  String _walletBalanceStr = "0.00";
  late AnimationController _waController;

  @override
  void initState() {
    super.initState();
    NoScreenshot.instance.screenshotOff();
    _waController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ANCHOR ANCESTORS FOR SAFE ASYNC USAGE
    final wp = Provider.of<WorkspaceProvider>(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final workspace = wp.activeWorkspace;
    final activeId = workspace?.id;
    
    if (_lastWorkspaceId != activeId) {
      _lastWorkspaceId = activeId;
      if (workspace != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            theme.setTenant(workspace.theme, themeColor: workspace.themeColor);
            _fetch();
          }
        });
      }
    }
  }

  void _showResultPrompt({required bool success, String? message}) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
              decoration: BoxDecoration(color: (success ? Colors.green : Colors.red).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, color: success ? Colors.green : Colors.red, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              success ? (lang.translate('success') ?? 'Success!') : (lang.translate('failure') ?? 'Error'),
              style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? (success ? lang.translate('operation_success') ?? 'Operation completed.' : lang.translate('operation_failure') ?? 'Please try again.'),
              style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(lang.translate('confirm') ?? 'OK', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _fetch() async {
    if (!mounted) return;
    
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    
    // IF WE HAVE CACHED DATA AND IT IS THE SAME WORKSPACE, USE IT IMMEDIATELY
    if (wp.isEagerLoaded && wp.cachedDashboard != null) {
      final cached = wp.cachedDashboard!;
      final favsRes = wp.cachedFavorites ?? {'favorites': []};
      final balRes = wp.cachedWallet ?? {'balance': '0.00'};
      
      final data = Map<String, dynamic>.from(cached);
      data['favorites_list'] = favsRes['favorites'] ?? [];
      
      setState(() {
        _dashboardData = data;
        _walletBalanceStr = (balRes['balance'] ?? balRes['wallet_balance'] ?? "0").toString();
        _isLoading = false;
      });
      
      // OPTIONAL: RE-FETCH IN BACKGROUND TO KEEP IT FRESH WITHOUT SHOWING LOADER
      _backgroundRefresh();
      return;
    }

    setState(() { _isLoading = true; _dashboardData = null; });
    try {
      final active = wp.activeWorkspace;
      
      // PARALLEL FETCH
      final futures = [
        if (active != null) wp.enrichWorkspace(active.id, context),
        wp.getDashboard(),
        wp.getFavorites(),
        wp.getWalletBalance(),
      ];
      
      final results = await Future.wait(futures);
      final dashboardIdx = active != null ? 1 : 0;
      final favsIdx = active != null ? 2 : 1;
      final balIdx = active != null ? 3 : 2;

      final data = Map<String, dynamic>.from(results[dashboardIdx] as Map);
      final favsRes = results[favsIdx] as Map<String, dynamic>;
      final balRes = results[balIdx] as Map<String, dynamic>;

      data['favorites_list'] = favsRes['favorites'] ?? [];
      
      if (mounted) {
        setState(() { 
          _dashboardData = data; 
          _walletBalanceStr = (balRes['balance'] ?? balRes['wallet_balance'] ?? "0").toString();
          _isLoading = false; 
        });
      }
    } catch (e) {
      debugPrint('Fetch Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _backgroundRefresh() async {
     try {
       final wp = Provider.of<WorkspaceProvider>(context, listen: false);
       await wp.eagerLoad(); // This updates the cache
       if (mounted) {
         final cached = wp.cachedDashboard;
         if (cached != null) {
            final data = Map<String, dynamic>.from(cached);
            data['favorites_list'] = (wp.cachedFavorites?['favorites'] ?? []);
            setState(() {
              _dashboardData = data;
              _walletBalanceStr = (wp.cachedWallet?['balance'] ?? wp.cachedWallet?['wallet_balance'] ?? "0").toString();
            });
         }
       }
     } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final workspace = wp.activeWorkspace;
    final isRTL = lang.currentLocale.languageCode == 'ar';
    
    // TYPE-RESILIENT DATA PARSING
    final dynamic rawDataObj = _dashboardData?['data'] ?? _dashboardData;
    final Map<String, dynamic> rawData = rawDataObj is Map<String, dynamic> ? rawDataObj : {};
    
    final List apiCourses = (rawData['courses'] as List?) ?? [];
    final List allCoursesRaw = (rawData['all_courses'] as List?) ?? json.decode(workspace?.latestCoursesJson ?? '[]');
    
    debugPrint('=== ALL COURSES (WORKSPACE METADATA) ===');
    debugPrint(json.encode(allCoursesRaw));
    debugPrint('========================================');
    
    final List favoritesList = (rawData['favorites_list'] as List?) ?? [];
    final Set<int> favoriteIds = favoritesList.map((f) => int.tryParse(f['id']?.toString() ?? '0') ?? 0).toSet();
    
    // API returns strictly enrolled courses with progress
    final List enrolledCourses = apiCourses.map((c) {
      final map = Map<String, dynamic>.from(c);
      final cid = int.tryParse(map['id']?.toString() ?? '0') ?? 0;
      map['enrolled'] = true; // explicitly force true
      map['is_favorite'] = favoriteIds.contains(cid);
      return map;
    }).toList();
    
    final Set<int> enrolledIds = enrolledCourses.map((c) => int.tryParse(c['id']?.toString() ?? '0') ?? 0).toSet();
    
    // Available courses are all courses minus the enrolled ones
    final List availableCourses = allCoursesRaw.map((c) {
      final map = Map<String, dynamic>.from(c);
      final cid = int.tryParse(map['id']?.toString() ?? '0') ?? 0;
      
      // Check for any implicit enrollment flags from metadata
      final dynamic e = map['enrolled'] ?? map['is_enrolled'] ?? map['is_purchased'] ?? map['is_admitted'] ?? map['isEnrolled'];
      final bool alreadyEnrolledByFlag = e == true || e == 1 || e == '1' || e == 'true';
      map['enrolled'] = alreadyEnrolledByFlag; 
      
      map['is_favorite'] = favoriteIds.contains(cid);
      return map;
    }).where((c) {
      final cid = int.tryParse(c['id']?.toString() ?? '0') ?? 0;
      final bool alreadyEnrolled = enrolledIds.contains(cid) || (c['enrolled'] == true);
      return !alreadyEnrolled && cid > 0;
    }).toList();
    
    final Map<String, dynamic> stats = rawData['stats'] is Map ? rawData['stats'] : {};
    final Map<String, dynamic> user = rawData['user'] is Map ? rawData['user'] : {};

    final walletBalance = _walletBalanceStr != "0.00" ? _walletBalanceStr : (user['wallet_balance'] ?? stats['walletBalance'] ?? stats['wallet_balance'] ?? 0).toString();
    final totalCoursesCount = (stats['totalCourses'] ?? stats['total_courses'] ?? enrolledCourses.length).toString();
    final studyHoursValue = (stats['studyHours'] ?? stats['study_hours'] ?? "0").toString();
    final pointsValue = (stats['points'] ?? "0").toString();

    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final List features = json.decode(workspace?.featuresJson ?? '[]');

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      drawer: _buildLuxurySidebar(wp, lang, theme, workspace, primaryColor, isRTL),
      body: Stack(
        children: [
          // TOP BRANDING GRADIENT
          Positioned(
            top: 0, left: 0, right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [primaryColor.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          

            
          SafeArea(
            child: Column(
              children: [
                // HEADER SECTION (Fixed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 24), // MOVED DOWN
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: primaryColor.withOpacity(0.08), width: 1),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, 10)),
                        BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 20, spreadRadius: -5),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // STUDENT AVATAR / INITIALS
                            Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                              ),
                              child: Center(
                                child: Text(
                                  (workspace?.studentName ?? 'S').substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${lang.translate('welcome_back')},", 
                                    style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    workspace?.studentName ?? 'Student', 
                                    style: TextStyle(color: onSurface, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.1)
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(color: onSurface.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                              child: IconButton(
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(), 
                                icon: Icon(Icons.grid_view_rounded, color: onSurface.withOpacity(0.7), size: 22)
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // ACADEMY BADGE & PROGRESS QUICK VIEW
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: onSurface.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: onSurface.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: workspace?.logoUrl != null 
                                    ? Image.network(workspace!.logoUrl!, fit: BoxFit.contain, errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: primaryColor, size: 16))
                                    : Icon(Icons.school_rounded, color: primaryColor, size: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(workspace?.name ?? 'Academy', style: TextStyle(color: onSurface, fontSize: 13, fontWeight: FontWeight.w900)),
                                    Text(lang.translate('active_now'), style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, color: onSurface.withOpacity(0.2), size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // BOX STATS (2x2 GRID - NO SCROLL)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildHeaderBox(context, lang.translate('wallet_balance').toUpperCase(), "${walletBalance} ${lang.translate('currency_le')}", Icons.account_balance_wallet_rounded, primaryColor, false, () {
                            Navigator.pushNamed(context, '/wallet');
                          })),
                          const SizedBox(width: 12),
                          Expanded(child: _buildHeaderBox(context, lang.translate('redeem_coupon').toUpperCase(), lang.translate('activate_now'), Icons.qr_code_scanner_rounded, primaryColor, true, () {
                            Navigator.pushNamed(context, '/onboarding');
                          })),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildMiniStat(lang.translate('my_courses'), totalCoursesCount, Icons.book_rounded, primaryColor)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildMiniStat(lang.translate('study_hours'), studyHoursValue, Icons.timer_rounded, primaryColor)),
                        ],
                      ),
                    ],
                  ),
                ),

                // SCROLLABLE CONTENT (FEATURES & COURSES)
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetch,
                    color: primaryColor,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        const SizedBox(height: 16), // REMOVED FEATURES LIST

                        const SizedBox(height: 16), // REMOVED WP BRANDING SEAL

                        const SizedBox(height: 16),
                        
                        if (_isLoading && enrolledCourses.isEmpty && availableCourses.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 80), child: PremiumLoader()))
                        else if (enrolledCourses.isEmpty && availableCourses.isEmpty)
                          _buildEmptyState(lang)
                        else ...[
                          if (enrolledCourses.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(lang.translate('my_courses') ?? 'Enrolled Courses', style: TextStyle(color: onSurface, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/all-courses'), 
                                  child: Row(
                                    children: [
                                      Text(lang.translate('view_all') ?? 'View All', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 4),
                                      Icon(isRTL ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded, size: 12, color: primaryColor),
                                    ],
                                  )
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...List.generate(enrolledCourses.length, (i) => _buildSaaSCourseCard(enrolledCourses[i], i, lang, primaryColor, isRTL)),
                          ],
                          
                          if (availableCourses.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(lang.translate('all_courses') ?? 'Available Courses', style: TextStyle(color: onSurface, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...List.generate(availableCourses.length, (i) => _buildSaaSCourseCard(availableCourses[i], i, lang, primaryColor, isRTL)),
                          ],
                        ],
                        
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppPulse(String number, Color primary) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _waController, curve: Curves.easeInOut)),
      child: FloatingActionButton(
        onPressed: () => Provider.of<WorkspaceProvider>(context, listen: false).launchUrl('https://wa.me/${number.replaceAll('+', '')}'),
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.message_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feat, Color primary, Color onSurface) {
    return Container(
      width: 200, // INCREASED FOR LUXURY SCALE
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: primary.withOpacity(0.1), width: 2),
        boxShadow: [BoxShadow(color: primary.withOpacity(0.05), blurRadius: 20, spreadRadius: -5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.auto_awesome_rounded, color: primary, size: 24),
          ),
          const SizedBox(height: 16),
          Text(feat['title'] ?? '', style: TextStyle(color: onSurface, fontSize: 14, fontWeight: FontWeight.w900, height: 1.2)), // NO TRUNCATION
          const SizedBox(height: 8),
          HtmlWidget(
            feat['description'] ?? '', 
            textStyle: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
          ), // NO TRUNCATION
        ],
      ),
    );
  }

  Widget _buildHeaderBox(BuildContext context, String label, String val, IconData icon, Color color, bool isAccent, VoidCallback onTap) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isAccent ? color : Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: isAccent ? null : Border.all(color: Theme.of(context).dividerColor, width: 2)),
        child: Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: TextStyle(color: isAccent ? Colors.white.withOpacity(0.7) : onSurface.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              Text(val, style: TextStyle(color: isAccent ? Colors.white : onSurface, fontSize: 13, fontWeight: FontWeight.w900)),
            ])),
            Icon(icon, color: isAccent ? Colors.white : color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).dividerColor, width: 2)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          ])),
        ],
      ),
    );
  }

  Widget _buildSaaSCourseCard(Map<String, dynamic> course, int index, LanguageProvider lang, Color wsColor, bool isRTL) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final progress = double.tryParse(course['progress']?.toString() ?? '0') ?? 0;
    
    // ROBUST CATEGORY DETECTION (PRIORITIZE STRINGS OVER IDS)
    String catStr = "";
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).dividerColor, width: 1.5)),
      child: InkWell(
        onTap: () {
          final dynamic e = course['enrolled'] ?? course['is_enrolled'] ?? course['is_purchased'] ?? course['is_admitted'] ?? course['isEnrolled'];
          final isEnrolled = e == true || e == 1 || e == '1' || e == 'true';
          final cid = int.tryParse(course['id']?.toString() ?? '0') ?? 0;
          if (!isEnrolled) {
            Navigator.pushNamed(context, '/subscribe', arguments: course);
            return;
          }
          if (cid > 0) Navigator.pushNamed(context, '/course', arguments: cid);
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(course['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&q=80', width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 60, height: 60, color: Theme.of(context).dividerColor, child: const Icon(Icons.school_rounded, size: 24)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (catStr.isNotEmpty) ...[
                      Text(catStr.toUpperCase(), style: TextStyle(color: wsColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                    ],
                    Text(course['title'] ?? '', style: TextStyle(color: onSurface, fontSize: 14, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (course['enrolled'] == true || course['enrolled'] == 1 || course['enrolled'] == '1' || course['enrolled'] == 'true') ...[
                      const SizedBox(height: 4),
                      Text("${course['total_materials'] ?? 0} ${lang.translate('materials_count')}", style: TextStyle(color: wsColor, fontSize: 11, fontWeight: FontWeight.w900)),
                    ] else ...[
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 32),
                        child: HtmlWidget(
                          course['description'] ?? '', 
                          textStyle: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 11, height: 1.2, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ])),
                  InkWell(
                    onTap: () => _isLoading ? null : _toggleFavorite(course),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: (course['is_favorite'] == true || course['isFavorite'] == true) ? Colors.red.withOpacity(0.1) : Theme.of(context).dividerColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon((course['is_favorite'] == true || course['isFavorite'] == true) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: (course['is_favorite'] == true || course['isFavorite'] == true) ? Colors.red : onSurface.withOpacity(0.4), size: 18),
                    ),
                  ),
                ],

              ),
              const SizedBox(height: 12),
              if (course['enrolled'] == true || course['enrolled'] == 1 || course['enrolled'] == '1' || course['enrolled'] == 'true')
                ClipRRect(borderRadius: BorderRadius.circular(100), child: LinearProgressIndicator(value: progress / 100, minHeight: 6, backgroundColor: Theme.of(context).dividerColor, valueColor: AlwaysStoppedAnimation<Color>(wsColor)))
              else
                Align(
                  alignment: isRTL ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: wsColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: wsColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
                    child: Text((lang.translate('subscribe') ?? 'SUBSCRIBE').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lang) {
    return Column(
      children: [
        const SizedBox(height: 60),
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
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            lang.translate('empty_courses_subtitle') ?? 'Explore our wide range of courses specifically designed for you.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 13, height: 1.5, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildLuxurySidebar(WorkspaceProvider wp, LanguageProvider lang, ThemeProvider theme, Workspace? workspace, Color wsColor, bool isRTL) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final cardColor = Theme.of(context).cardColor;
    
    return Container(
      width: 290,
      child: Drawer(
        backgroundColor: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(isRTL ? 0 : 40), bottomRight: Radius.circular(isRTL ? 0 : 40), topLeft: Radius.circular(isRTL ? 40 : 0), bottomLeft: Radius.circular(isRTL ? 40 : 0))),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 60, 24, 32),
              decoration: BoxDecoration(color: wsColor.withOpacity(0.12), borderRadius: BorderRadius.only(bottomRight: Radius.circular(40), bottomLeft: Radius.circular(isRTL ? 40 : 0))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (workspace?.logoUrl != null)
                        Container(
                          width: 56, height: 56,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: wsColor.withOpacity(0.2), width: 1.5)),
                          child: ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.network(workspace!.logoUrl!, fit: BoxFit.contain, errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: wsColor, size: 24))),
                        )
                      else
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(color: wsColor, shape: BoxShape.circle),
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                        ),
                      
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(workspace?.name ?? 'Academy', style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                IconButton(onPressed: () => theme.toggleTheme(), icon: Icon(theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: wsColor, size: 20)),
                              ],
                            ),
                            Text(workspace?.studentName ?? 'Student Profile', style: TextStyle(color: onSurface.withOpacity(0.4), fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
                    child: Text((lang.translate('main_menu') ?? 'MAIN MENU').toUpperCase(), style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  _buildSidebarAction(icon: Icons.grid_view_rounded, title: lang.translate('dashboard'), onTap: () => Navigator.pop(context), isSelected: true, wsColor: wsColor),
                  _buildSidebarAction(icon: Icons.library_books_rounded, title: lang.translate('all_courses') ?? 'All Courses', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/all-courses'); }, wsColor: wsColor),
                  _buildSidebarAction(icon: Icons.favorite_rounded, title: lang.translate('favorites') ?? 'Favorites', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/favorites'); }, wsColor: wsColor),
                  
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
                    child: Text((lang.translate('academy') ?? 'ACADEMY').toUpperCase(), style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  _buildSidebarAction(icon: Icons.auto_awesome_rounded, title: lang.translate('academy_highlights') ?? 'Academy Highlights', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/highlights'); }, wsColor: wsColor),
                  _buildSidebarAction(icon: Icons.help_outline_rounded, title: lang.translate('faqs') ?? 'FAQs', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/faqs'); }, wsColor: wsColor),
                  
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
                    child: Text((lang.translate('account') ?? 'ACCOUNT & BILLING').toUpperCase(), style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  _buildSidebarAction(icon: Icons.person_rounded, title: lang.translate('profile'), onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/profile'); }, wsColor: wsColor),
                  _buildSidebarAction(icon: Icons.account_balance_wallet_rounded, title: lang.translate('wallet_balance') ?? 'Academy Wallet', onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/wallet'); }, wsColor: wsColor),
                  
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Text((lang.translate('other_workspaces') ?? 'OTHER ACADEMIES').toUpperCase(), style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(width: 8),
                      Expanded(child: Divider(color: onSurface.withOpacity(0.05), thickness: 2)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...wp.workspaces.map((w) => _buildAcademyPill(w, workspace?.id == w.id, wsColor, wp)),
                ],
              ),
            ),
            
            if (workspace?.whatsappNumber != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: InkWell(
                  onTap: () => wp.launchUrl("https://wa.me/${workspace!.whatsappNumber!}"),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 18), const SizedBox(width: 12), Text(lang.translate('teacher_support') ?? 'Teacher Support', style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w900, fontSize: 14))]),
                  ),
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: InkWell(
                onTap: () async { 
                  final nav = Navigator.of(context);
                  nav.pop(); // Close drawer
                  await wp.logout();
                  nav.pushNamedAndRemoveUntil('/onboarding', (r) => false);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 18), const SizedBox(width: 12), Text(lang.translate('logout'), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 14))]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarAction({required IconData icon, required String title, required VoidCallback onTap, bool isSelected = false, required Color wsColor}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: isSelected ? wsColor : Colors.transparent, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [Icon(icon, color: isSelected ? Colors.white : onSurface.withOpacity(0.6), size: 20), const SizedBox(width: 16), Text(title, style: TextStyle(color: isSelected ? Colors.white : onSurface, fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, fontSize: 14))]),
        ),
      ),
    );
  }

  Widget _buildAcademyPill(Workspace w, bool isSelected, Color wsColor, WorkspaceProvider wp) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () { 
          Navigator.pop(context); 
          setState(() { _isLoading = true; _dashboardData = null; }); // IMMEDIATE LOADING
                  wp.switchWorkspace(w.id, context); 
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? wsColor.withOpacity(0.08) : Theme.of(context).dividerColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? wsColor.withOpacity(0.2) : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              (w.logoUrl != null)
                 ? Container(width: 38, height: 38, padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: isSelected ? wsColor : Colors.transparent, width: 1)), child: ClipRRect(borderRadius: BorderRadius.circular(19), child: Image.network(w.logoUrl!, fit: BoxFit.contain, errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: wsColor, size: 14))))
                 : Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isSelected ? wsColor : onSurface.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.school_rounded, color: isSelected ? Colors.white : onSurface.withOpacity(0.3), size: 14)),
              
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.name.toUpperCase(), style: TextStyle(color: isSelected ? onSurface : onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                Text(w.host.toLowerCase(), style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold)),
              ])),
              if (isSelected) Container(width: 6, height: 6, decoration: BoxDecoration(color: wsColor, shape: BoxShape.circle)),
            ],
          ),
        ), 
      ),
    ); 
  }
}
