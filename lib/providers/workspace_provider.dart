import 'package:flutter/material.dart';
import 'package:learnock_drm/models/workspace.dart';
import 'package:learnock_drm/providers/theme_provider.dart';
import 'package:learnock_drm/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'dart:convert';

class WorkspaceProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _cachedDashboard;
  Map<String, dynamic>? _cachedFavorites;
  Map<String, dynamic>? _cachedWallet;
  Map<String, dynamic>? _cachedME;
  bool _isInitialized = false;
  bool _isEagerLoaded = false;
  final Map<int, Map<String, dynamic>> _lastAccessedMaterials = {};
  final Set<int> _localFavoriteIds = {}; // TRUTH FOR OPTIMISTIC FAVS (Shared across screens)


  bool get isInitialized => _isInitialized;
  bool get isEagerLoaded => _isEagerLoaded;
  Map<String, dynamic>? get cachedDashboard => _cachedDashboard;
  Map<String, dynamic>? get cachedFavorites => _cachedFavorites;
  Map<String, dynamic>? get cachedWallet => _cachedWallet;
  Map<String, dynamic>? get cachedME => _cachedME;
  Map<int, Map<String, dynamic>> get lastAccessedMaterials => _lastAccessedMaterials;
  Set<int> get localFavoriteIds => _localFavoriteIds;


  Workspace? get activeWorkspace => _apiService.activeWorkspace;
  List<Workspace> get workspaces => _apiService.workspaces;
  String get deviceId => _apiService.deviceId;

  Future<void> init() async {
    await _apiService.init();
    _isInitialized = true;
    if (activeWorkspace != null) {
      await eagerLoad();
    }
    notifyListeners();
  }

  Future<void> eagerLoad([BuildContext? context]) async {
    if (activeWorkspace == null) return;
    
    _isEagerLoaded = false;
    // FETCH EVERYTHING SIMULTANEOUSLY
    final futures = [
      enrichWorkspace(activeWorkspace!.id, context),
      getDashboard(),
      getFavorites(),
      getWalletBalance(),
      getMe(),
    ];

    try {
      final results = await Future.wait(futures);
      _cachedDashboard = results[1] as Map<String, dynamic>;
      _cachedFavorites = results[2] as Map<String, dynamic>;
      _cachedWallet = results[3] as Map<String, dynamic>;
      _cachedME = results[4] as Map<String, dynamic>;
      
      // SYNC FAVORITES SET
      final List favs = (_cachedFavorites?['favorites'] as List?) ?? [];
      _localFavoriteIds.clear();
      _localFavoriteIds.addAll(favs.map((f) => int.tryParse(f['id']?.toString() ?? '0') ?? 0).where((id) => id != 0));

      _isEagerLoaded = true;
      debugPrint('🚀 EAGER LOAD COMPLETE: All data cached. Favs: ${_localFavoriteIds.length}');
    } catch (e) {
      debugPrint('❌ Eager Load Error: $e');
    }
    notifyListeners();
  }

  Future<void> enrichWorkspace(String id, [BuildContext? context]) async {
    try {
      final response = await _apiService.getSiteSettings();
      final workspacesList = List<Workspace>.from(_apiService.workspaces);
      final index = workspacesList.indexWhere((w) => w.id == id);
      
      if (index != -1) {
        final w = workspacesList[index];
        final tenant = response['tenant'] as Map<String, dynamic>?;
        final settings = response['settings'] as Map<String, dynamic>?;
        final courses = response['courses'] as List?;
        
        final updated = w.copyWith(
          teacherName: tenant?['teacher_name'] ?? w.teacherName,
          theme: tenant?['theme'] ?? settings?['theme'] ?? w.theme,
          heroTitle: settings?['hero_title'],
          heroSubtitle: settings?['hero_subtitle'],
          aboutTeacher: settings?['about_teacher'],
          whatsappNumber: settings?['whatsapp_number'],
          logoUrl: settings?['logo_url'],
          themeColor: settings?['theme_color'],
          faqsJson: json.encode(settings?['faqs'] ?? []),
          featuresJson: json.encode(settings?['features'] ?? []),
          latestCoursesJson: json.encode(courses ?? []),
          enablePurchasing: (settings?['enable_purchasing'] == 1 || settings?['enable_purchasing'] == true),
        );
        
        await _apiService.addWorkspace(updated);
        
        // AUTO-SYNC THEME IF CONTEXT PROVIDED
        if (context != null) {
          try {
            final tp = Provider.of<ThemeProvider>(context, listen: false);
            final sColor = updated.themeColor;
            debugPrint('🔥🔥 Academy Branding Sync: Color detected -> $sColor');
            tp.setTenant(updated.theme, themeColor: sColor);
          } catch (e) {
            debugPrint('⚠️ Theme Sync Error: $e');
          }
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Branding Enrich Error: $e');
      if (e.toString().contains('Tenant not registered')) {
        debugPrint('⚠️ CRITICAL: Tenant revoked or not found. Purging workspace ID: $id');
        await removeWorkspace(id);
        
        // If we have a context, force a reset to the root to show onboarding/selection
        if (context != null && context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    }
  }

  Future<void> addWorkspaceWithToken(String host, String token, String email, String name) async {
    final tenantName = host.split('.').first;
    final workspace = Workspace(
      id: '$tenantName-$email',
      tenant: tenantName,
      host: host,
      name: tenantName.toUpperCase(),
      studentName: name,
      email: email,
      token: token,
      deviceId: deviceId,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _apiService.addWorkspace(workspace);
    await enrichWorkspace(workspace.id);
    notifyListeners();
  }

  Future<void> addWorkspaceManual(String host, String email, String password) async {
    final loginData = await _apiService.login(host, email, password);
    final token = loginData['token'];
    final user = loginData['user'];
    final tenantName = host.split('.').first;

    final workspace = Workspace(
      id: '$tenantName-$email',
      tenant: tenantName,
      host: host,
      name: tenantName.toUpperCase(),
      studentName: user['name'] ?? '',
      email: email,
      token: token,
      deviceId: deviceId,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _apiService.addWorkspace(workspace);
    await enrichWorkspace(workspace.id);
    notifyListeners();
  }

  Future<void> switchWorkspace(String id, [BuildContext? context]) async {
    final workspace = workspaces.firstWhere((w) => w.id == id);
    
    // IMMEDIATE THEME SYNC IF CONTEXT PROVIDED
    if (context != null) {
      try {
        final tp = Provider.of<ThemeProvider>(context, listen: false);
        tp.setTenant(workspace.theme, themeColor: workspace.themeColor);
      } catch (_) {}
    }
    
    await _apiService.switchWorkspace(id);
    await eagerLoad(context);
    notifyListeners();
  }

  Future<void> logout() async {
    await _apiService.clearSession();
    notifyListeners();
  }

  Future<void> removeWorkspace(String id) async {
    await _apiService.removeWorkspace(id);
    notifyListeners();
  }

  Future<Map<String, dynamic>> getDashboard() => _apiService.getDashboard();
  Future<Map<String, dynamic>> getCourse(int id) => _apiService.getCourse(id);
  Future<Map<String, dynamic>> getCourseLearn(int id) => _apiService.getCourseLearn(id);
  Future<Map<String, dynamic>> getPlayback(String code) => _apiService.getPlayback(code);
  
  Future<void> markProgress(int courseId, Map<String, dynamic> material) async {
    final materialId = int.tryParse(material['id']?.toString() ?? '0') ?? 0;
    if (materialId != 0) await _apiService.markProgress(courseId, materialId);
    _lastAccessedMaterials[courseId] = material;
    notifyListeners();
  }
  
  Future<Map<String, dynamic>> toggleFavorite(int courseId) => _apiService.toggleFavorite(courseId);

  Future<void> toggleFavoriteOptimistic(int courseId) async {
    final bool wasFav = _localFavoriteIds.contains(courseId);
    
    // 1. UPDATE LOCALLY FIRST (notify all screens)
    if (wasFav) {
      _localFavoriteIds.remove(courseId);
    } else {
      _localFavoriteIds.add(courseId);
    }
    notifyListeners();

    // 2. BACKEND SYNC
    try {
      await _apiService.toggleFavorite(courseId);
      // Optional: re-fetch favorites list in background to keep full movie objects fresh
      getFavorites().then((res) {
        _cachedFavorites = res;
        final List favs = (res['favorites'] as List?) ?? [];
        _localFavoriteIds.clear();
        _localFavoriteIds.addAll(favs.map((f) => int.tryParse(f['id']?.toString() ?? '0') ?? 0).where((id) => id != 0));
        notifyListeners();
      });
    } catch (e) {
      // REVERT ON ERROR
      if (wasFav) {
        _localFavoriteIds.add(courseId);
      } else {
        _localFavoriteIds.remove(courseId);
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getFavorites() => _apiService.getFavorites();

  Future<Map<String, dynamic>> redeemCoupon(String code) => _apiService.redeemCoupon(code);
  Future<Map<String, dynamic>> redeemVoucher(String code) => _apiService.redeemVoucher(code);
  Future<Map<String, dynamic>> checkoutWallet(int courseId) => _apiService.checkoutWallet(courseId);
  Future<Map<String, dynamic>> unenroll(int courseId) => _apiService.unenroll(courseId);
  
  Future<Map<String, dynamic>> getWalletTransactions() => _apiService.getWalletTransactions();
  Future<Map<String, dynamic>> getWalletBalance() => _apiService.getWalletBalance();
  
  Future<Map<String, dynamic>> getCourses({int? categoryId}) async {
     final path = categoryId != null ? '/courses?categoryId=$categoryId' : '/courses';
     final res = await _apiService.request('GET', path);
     return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> getCategories() => _apiService.getCategories();
  
  Future<Map<String, dynamic>> getMe() => _apiService.getMe();
  Future<Map<String, dynamic>> getGroups() => _apiService.getGroups();
  Future<Map<String, dynamic>> joinGroup(int groupId) => _apiService.joinGroup(groupId);
  
  Future<Map<String, dynamic>> submitQuiz(int quizId, dynamic results) => _apiService.submitQuiz(quizId, results);
  Future<Map<String, dynamic>> getReviews(int courseId) => _apiService.getReviews(courseId);
  Future<Map<String, dynamic>> submitReview(int courseId, int rating, String comment) => _apiService.submitReview(courseId, rating, comment);
  Future<Map<String, dynamic>> getImageKitAuth() => _apiService.getImageKitAuth();
  Future<Map<String, dynamic>> getSchedule() => _apiService.getSchedule();

  Future<void> launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await launcher.canLaunchUrl(uri)) {
        await launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}
