// lib/core/session.dart
import 'package:flutter/foundation.dart';
import 'rbac.dart';

class Session extends ChangeNotifier {
  Session._();
  static final Session i = Session._();

  // usuário atual (guarde apenas o essencial que a UI usa)
  String? userId;
  String? username;

  AccessProfile? _profile;

  bool get logged => userId != null;
  AccessProfile? get profile => _profile;

  String get role => _profile?.role ?? '';
  List<String> get pages => _profile?.pages ?? const [];
  List<String> get caps => _profile?.caps ?? const [];

  bool can(String cap) => _profile?.can(cap) ?? false;
  bool show(String page) => _profile?.showPage(page) ?? false;

  void setUser({required String? id, required String? name}) {
    userId = id;
    username = name;
    notifyListeners();
  }

  void setProfile(AccessProfile? p) {
    _profile = p;
    notifyListeners();
  }

  Future<void> clear() async {
    userId = null;
    username = null;
    _profile = null;
    notifyListeners();
  }
}
