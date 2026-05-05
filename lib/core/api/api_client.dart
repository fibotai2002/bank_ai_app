import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ApiClient {
  // Android emulyator: 10.0.2.2 | iOS simulator: localhost | Real qurilma: serverIP
  static const baseUrl = 'http://10.0.2.2:8000';

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ));

    // JWT token interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post('/api/auth/login',
        data: {'username': username, 'password': password});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/api/auth/me');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/auth/me', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Users ─────────────────────────────────────────────────────────────────
  Future<List<dynamic>> getUsers() async {
    final res = await _dio.get('/api/users');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/users', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteUser(int userId) async {
    await _dio.delete('/api/users/$userId');
  }

  // ── Departments ───────────────────────────────────────────────────────────
  Future<List<dynamic>> getDepartments() async {
    final res = await _dio.get('/api/departments');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createDepartment(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/departments', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Chat ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> chat(String message, int telegramId) async {
    final res = await _dio.post('/api/chat',
        data: {'message': message, 'telegram_id': telegramId});
    return res.data as Map<String, dynamic>;
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────
  Future<List<dynamic>> getTasks(
      {String? status, String? department, String? priority}) async {
    final res = await _dio.get('/api/tasks', queryParameters: {
      if (status != null) 'status': status,
      if (department != null) 'department': department,
      if (priority != null) 'priority': priority,
    });
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getMyTasks({String? status}) async {
    final res = await _dio.get('/api/tasks/my', queryParameters: {
      if (status != null) 'status': status,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/tasks', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> updateTaskStatus(int id, String status) async {
    await _dio.patch('/api/tasks/$id/status',
        queryParameters: {'status': status});
  }

  Future<Map<String, dynamic>> updateTask(
      int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/tasks/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> assignTask(
      int taskId, int assigneeId, {String? message}) async {
    final res = await _dio.post('/api/tasks/$taskId/assign',
        data: {'assignee_id': assigneeId, if (message != null) 'message': message});
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteTask(int id) async {
    await _dio.delete('/api/tasks/$id');
  }

  // ── Employees (eski moslik) ───────────────────────────────────────────────
  Future<List<dynamic>> getEmployees() async {
    final res = await _dio.get('/api/employees');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getEmployee(int telegramId) async {
    final res = await _dio.get('/api/employees/$telegramId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createEmployee(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/api/employees', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEmployee(
      int telegramId, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/employees/$telegramId', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<List<dynamic>> getMyNotifications() async {
    final res = await _dio.get('/api/notifications');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getNotifications(int telegramId) async {
    final res = await _dio.get('/api/notifications/$telegramId');
    return res.data as List<dynamic>;
  }

  Future<void> markNotificationRead(int notifId) async {
    await _dio.patch('/api/notifications/$notifId/read');
  }

  Future<void> markAllNotificationsRead(int telegramId) async {
    await _dio.patch('/api/notifications/read-all/$telegramId');
  }

  Future<void> markAllMyNotificationsRead() async {
    await _dio.patch('/api/notifications/read-all/me');
  }

  // ── Documents ─────────────────────────────────────────────────────────────
  Future<List<dynamic>> getDocuments() async {
    final res = await _dio.get('/api/documents');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> uploadDocument(
      File file, int telegramId) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path,
          filename: file.path.split('/').last),
    });
    final res = await _dio.post('/api/documents/upload',
        data: formData, queryParameters: {'telegram_id': telegramId});
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteDocument(int docId) async {
    await _dio.delete('/api/documents/$docId');
  }

  // ── Stats ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getStats() async {
    final res = await _dio.get('/api/stats');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getDepartmentStats() async {
    final res = await _dio.get('/api/stats/departments');
    return res.data as List<dynamic>;
  }
}
