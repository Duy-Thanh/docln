import 'package:flutter/services.dart';

class PerformanceService {
  static const _channel = MethodChannel('com.cyberdaystudios.apps.docln/performance');
  static double _currentFPS = 0;
  
  static final PerformanceService _instance = PerformanceService._internal();
  
  factory PerformanceService() => _instance;
  
  PerformanceService._internal() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  Future<void> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onFPSUpdate':
        _currentFPS = call.arguments['fps'];
        break;
    }
  }

  static Future<void> optimizeScreen(String screenName) async {
    await _channel.invokeMethod('optimizeScreen', {'screenName': screenName});
  }

  static Future<double> getCurrentFPS() async {
    return _currentFPS;
  }

  static Future<Map<String, dynamic>> getMemoryInfo() async {
    final result = await _channel.invokeMethod('getMemoryInfo');
    return Map<String, dynamic>.from(result);
  }
}