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

  Future<dynamic> _request(
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
    if (method == 'POST') {
      print('>>> POST $uri');
      print('>>> Headers: $headers');
      print('>>> Body: $body');
      response = await http.post(uri, headers: headers, body: json.encode(body));
    } else {
      print('>>> GET $uri');
      print('>>> Headers: $headers');
      response = await http.get(uri, headers: headers);
    }

    print('<<< Status: ${response.statusCode}');
    print('<<< Body: ${response.body}');

    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }

    final data = json.decode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['error'] ?? data['message'] ?? 'API Error');
    }
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
    return await _request('GET', '/courses/playback/$code');
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final futures = [
      _request('GET', '/dashboard/stats'),
      _request('GET', '/dashboard/courses').catchError((_) => {'courses': []}),
      _request('GET', '/courses').catchError((_) => {'courses': [], 'categories': []}),
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
    return await _request('GET', '/courses');
  }

  Future<Map<String, dynamic>> getCourse(int id) async {
    return await _request('GET', '/courses/$id');
  }

  Future<void> markProgress(int courseId, int materialId) async {
    await _request('POST', '/courses/$courseId/progress', body: {
      'materialId': materialId,
    });
  }

  Future<Map<String, dynamic>> toggleFavorite(int courseId) async {
    return await _request('POST', '/courses/favorite', body: {'courseId': courseId});
  }

  Future<Map<String, dynamic>> getFavorites() async {
    return await _request('GET', '/courses/favorite');
  }

  Future<Map<String, dynamic>> getSiteSettings() async {
    return await _request('GET', '/site-settings');
  }

  Future<Map<String, dynamic>> redeemCoupon(String code) async {
    return await _request('POST', '/coupons/redeem', body: {'code': code});
  }

  Future<Map<String, dynamic>> redeemVoucher(String code) async {
    return await _request('POST', '/vouchers/redeem', body: {'code': code});
  }

  Future<Map<String, dynamic>> checkoutWallet(int courseId) async {
    return await _request('POST', '/checkout/wallet', body: {'courseId': courseId});
  }

  Future<Map<String, dynamic>> getWalletTransactions() async {
    return await _request('GET', '/wallet/transactions');
  }

  Future<Map<String, dynamic>> getWalletBalance() async {
    return await _request('GET', '/wallet/status');
  }
}
