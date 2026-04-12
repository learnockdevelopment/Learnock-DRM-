import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:learnock_drm/models/workspace.dart';
import 'package:learnock_drm/models/app_state.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class ApiService {
  final _storage = const FlutterSecureStorage();
  final _stateKey = 'app_state';
  AppState? _state;
  String? _deviceId;

  Future<void> init() async {
    final stateStr = await _storage.read(key: _stateKey);
    if (stateStr != null) {
      _state = AppState.fromJson(json.decode(stateStr));
    } else {
      _state = AppState(workspaces: []);
    }

    _deviceId = await _storage.read(key: 'device_id');
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await _storage.write(key: 'device_id', value: _deviceId!);
    }
  }

  String get deviceId => _deviceId ?? 'unknown';
  List<Workspace> get workspaces => _state?.workspaces ?? [];
  Workspace? get activeWorkspace {
    if (_state?.activeWorkspaceId == null) return null;
    return _state?.workspaces.firstWhere(
      (w) => w.id == _state!.activeWorkspaceId,
      orElse: () => _state!.workspaces.first,
    );
  }

  Future<void> _saveState() async {
    if (_state != null) {
      await _storage.write(key: _stateKey, value: json.encode(_state!.toJson()));
    }
  }

  Future<void> addWorkspace(Workspace workspace) async {
    final workspaces = List<Workspace>.from(_state!.workspaces);
    workspaces.removeWhere((w) => w.id == workspace.id);
    workspaces.add(workspace);
    _state = AppState(
      workspaces: workspaces,
      activeWorkspaceId: workspace.id,
    );
    await _saveState();
  }

  Future<void> switchWorkspace(String id) async {
    _state = AppState(
      workspaces: _state!.workspaces,
      activeWorkspaceId: id,
    );
    await _saveState();
  }

  Future<void> clearSession() async {
    if (_state == null) return;
    _state = AppState(
      workspaces: _state!.workspaces,
      activeWorkspaceId: null,
    );
    await _saveState();
  }

  Future<void> clearAll() async {
    _state = AppState(workspaces: []);
    await _storage.delete(key: _stateKey);
  }

  Future<void> removeWorkspace(String id) async {
    final workspaces = List<Workspace>.from(_state!.workspaces);
    workspaces.removeWhere((w) => w.id == id);
    
    String? newActiveId = _state?.activeWorkspaceId;
    if (newActiveId == id) {
       newActiveId = workspaces.isNotEmpty ? workspaces.first.id : null;
    }

    _state = AppState(
      workspaces: workspaces,
      activeWorkspaceId: newActiveId,
    );
    await _saveState();
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Workspace? overrideWorkspace,
  }) async {
    final workspace = overrideWorkspace ?? activeWorkspace;
    if (workspace == null) throw Exception('No active workspace');

    final uri = Uri.https(workspace.host, '/api$path');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer ${workspace.token}',
    };

    if (method == 'POST') {
      headers['Content-Type'] = 'application/json';
    }

    http.Response response;
    int retryCount = 0;
    while (true) {
      try {
        if (method == 'POST') {
          print('>>> POST $uri');
          response = await http.post(uri, headers: headers, body: json.encode(body)).timeout(const Duration(seconds: 20));
        } else {
          print('>>> GET $uri');
          response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
        }
        break; // Success
      } catch (e) {
        retryCount++;
        if (retryCount >= 3 || method == 'POST') rethrow; // Don't retry POSTs to avoid duplicate actions
        print('>>> Retry $retryCount due to: $e');
        await Future.delayed(Duration(seconds: retryCount));
      }
    }

    print('<<< Status: ${response.statusCode}');
    if (response.statusCode == 401) throw Exception('Session expired');

    final data = json.decode(response.body);
    if (response.statusCode >= 400) throw Exception(data['error'] ?? data['message'] ?? 'API Error');
    return data;
  }

  Future<Map<String, dynamic>> login(String host, String email, String password) async {
      final uri = Uri.https(host, '/api/auth/login');
      print('>>> POST $uri');
      print('>>> Email: $email');
      
      final response = await http.post(
        uri,
        headers: {
          'Host': host,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      print('<<< Status: ${response.statusCode}');
      print('<<< Body: ${response.body}');

      final data = json.decode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? 'Login failed');
      }
      return data;
  }

  Future<Map<String, dynamic>> getPlayback(String code) async {
    return await request('GET', '/courses/playback/$code');
  }

  // REVISED FLOW: /api/courses/[id]/learn
  Future<Map<String, dynamic>> getCourseLearn(int id) async {
    return await request('GET', '/courses/$id/learn');
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final futures = [
      request('GET', '/dashboard/stats'),
      request('GET', '/dashboard/courses').catchError((_) => {'courses': []}),
      request('GET', '/courses').catchError((_) => {'courses': [], 'categories': []}),
    ];

    final results = await Future.wait(futures);
    
    final statsRes = Map<String, dynamic>.from(results[0]);
    final coursesRes = results[1] as Map<String, dynamic>;
    final allRes = results[2] as Map<String, dynamic>;

    statsRes['courses'] = coursesRes['courses'] ?? [];
    statsRes['all_courses'] = allRes['courses'] ?? [];
    statsRes['categories'] = allRes['categories'] ?? [];
    
    return statsRes;
  }

  Future<Map<String, dynamic>> getAllCourses() async {
    return await request('GET', '/courses');
  }

  Future<Map<String, dynamic>> getCourse(int id) async {
    return await request('GET', '/courses/$id');
  }

  Future<void> markProgress(int courseId, int materialId) async {
    await request('POST', '/courses/$courseId/progress', body: {
      'materialId': materialId,
    });
  }

  Future<Map<String, dynamic>> toggleFavorite(int courseId) async {
    return await request('POST', '/courses/favorite', body: {'courseId': courseId});
  }

  Future<Map<String, dynamic>> getFavorites() async {
    return await request('GET', '/courses/favorite');
  }

  Future<Map<String, dynamic>> getSiteSettings() async {
    return await request('GET', '/site-settings');
  }

  Future<Map<String, dynamic>> redeemCoupon(String code) async {
    return await request('POST', '/coupons/redeem', body: {'code': code});
  }

  Future<Map<String, dynamic>> redeemVoucher(String code) async {
    return await request('POST', '/vouchers/redeem', body: {'code': code});
  }

  Future<Map<String, dynamic>> checkoutWallet(int courseId) async {
    return await request('POST', '/checkout/wallet', body: {'courseId': courseId});
  }

  // REVISED FLOW: /api/courses/unenroll
  Future<Map<String, dynamic>> unenroll(int courseId) async {
    return await request('POST', '/courses/unenroll', body: {'courseId': courseId});
  }

  Future<Map<String, dynamic>> getWalletTransactions() async {
    return await request('GET', '/wallet/transactions');
  }

  Future<Map<String, dynamic>> getWalletBalance() async {
    return await request('GET', '/wallet/status');
  }

  // REVISED FLOW: /api/categories
  Future<Map<String, dynamic>> getCategories() async {
    return await request('GET', '/categories');
  }

  // REVISED FLOW: /api/quizzes/[id]/submit
  Future<Map<String, dynamic>> submitQuiz(int quizId, dynamic results) async {
    return await request('POST', '/quizzes/$quizId/submit', body: {'results': results});
  }

  // REVISED FLOW: /api/courses/[id]/reviews
  Future<Map<String, dynamic>> getReviews(int courseId) async {
    return await request('GET', '/courses/$courseId/reviews');
  }

  Future<Map<String, dynamic>> submitReview(int courseId, int rating, String comment) async {
    return await request('POST', '/courses/$courseId/reviews', body: {
      'rating': rating,
      'comment': comment,
    });
  }

  // REVISED FLOW: /api/imagekit/auth
  Future<Map<String, dynamic>> getImageKitAuth() async {
    return await request('GET', '/imagekit/auth');
  }

  // REVISED FLOW: /api/auth/me
  Future<Map<String, dynamic>> getMe() async {
    return await request('GET', '/auth/me');
  }

  // REVISED FLOW: /api/auth/batches
  Future<Map<String, dynamic>> getGroups() async {
    return await request('GET', '/auth/batches');
  }

  Future<Map<String, dynamic>> joinGroup(int groupId) async {
    return await request('POST', '/auth/batches', body: {'groupId': groupId});
  }

  // REVISED FLOW: /api/schedule
  Future<Map<String, dynamic>> getSchedule() async {
    return await request('GET', '/schedule');
  }
}
