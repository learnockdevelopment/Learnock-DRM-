import 'package:flutter/material.dart';
import 'package:learnock_drm/models/workspace.dart';
import 'package:learnock_drm/providers/theme_provider.dart';
import 'package:learnock_drm/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class WorkspaceProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  Workspace? get activeWorkspace => _apiService.activeWorkspace;
  List<Workspace> get workspaces => _apiService.workspaces;
  String get deviceId => _apiService.deviceId;

  Future<void> init() async {
    await _apiService.init();
    _isInitialized = true;
    if (activeWorkspace != null) {
      await enrichWorkspace(activeWorkspace!.id, null);
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
    await enrichWorkspace(id, context);
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
  Future<Map<String, dynamic>> getPlayback(String code) => _apiService.getPlayback(code);
  Future<void> markProgress(int courseId, int materialId) => _apiService.markProgress(courseId, materialId);
  Future<Map<String, dynamic>> toggleFavorite(int courseId) => _apiService.toggleFavorite(courseId);
  Future<Map<String, dynamic>> getFavorites() => _apiService.getFavorites();

  Future<Map<String, dynamic>> redeemCoupon(String code) => _apiService.redeemCoupon(code);
  Future<Map<String, dynamic>> redeemVoucher(String code) => _apiService.redeemVoucher(code);
  Future<Map<String, dynamic>> checkoutWallet(int courseId) => _apiService.checkoutWallet(courseId);
  Future<Map<String, dynamic>> getWalletTransactions() => _apiService.getWalletTransactions();
  Future<Map<String, dynamic>> getWalletBalance() => _apiService.getWalletBalance();

  Future<void> launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(url);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}
