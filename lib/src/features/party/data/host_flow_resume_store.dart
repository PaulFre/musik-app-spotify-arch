import 'package:shared_preferences/shared_preferences.dart';

class HostFlowResumeStore {
  HostFlowResumeStore._();

  static const String _pendingHostSetupKey = 'party.host_setup.pending_resume';

  static Future<void> markPendingHostSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingHostSetupKey, true);
  }

  static Future<bool> consumePendingHostSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_pendingHostSetupKey) ?? false;
    if (pending) {
      await prefs.remove(_pendingHostSetupKey);
    }
    return pending;
  }
}
