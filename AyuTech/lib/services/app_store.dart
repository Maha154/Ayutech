import 'package:shared_preferences/shared_preferences.dart';
import '../models/patient.dart';

class AppStore {
  AppStore._();
  static final AppStore _i = AppStore._();

  factory AppStore() => _i;

  String _identity(Patient p) =>
    '${p.name.trim().toLowerCase()}|'
    '${p.phoneNumber.trim()}|'
    '${p.startDate.toIso8601String()}';


  static const _kLoggedIn = 'logged_in';
  static const _kUser = 'user';
  static const _kPatients = 'patients';

  SharedPreferences? _sp; // changed from late to nullable

  Future<void> init() async {
    
    _sp ??= await SharedPreferences.getInstance();
  }

  // Ensure _sp is initialized before any usage
  Future<SharedPreferences> get _prefs async {
    _sp ??= await SharedPreferences.getInstance();
    return _sp!;
  }

  // LOGIN STATE
  Future<bool> get isLoggedIn async => (await _prefs).getBool(_kLoggedIn) ?? false;
  Future<String?> get user async => (await _prefs).getString(_kUser);

  Future<void> setLoggedIn({required bool value, String? username}) async {
    final sp = await _prefs;
    await sp.setBool(_kLoggedIn, value);
    if (username != null) await sp.setString(_kUser, username);
  }

  // PATIENTS LIST (persisted as JSON array)
  Future<List<Patient>> getPatients() async {
    final sp = await _prefs;
    final raw = sp.getStringList(_kPatients) ?? <String>[];
    return raw.map((s) {
      try {
        return Patient.fromJsonString(s);
      } catch (_) {
        return null;
      }
    }).whereType<Patient>().toList();
  }

  Future<void> savePatients(List<Patient> list) async {
    final sp = await _prefs;
    final enc = list.map((p) => p.toJsonString()).toList();
    await sp.setStringList(_kPatients, enc);
  }

 Future<void> addPatient(Patient p) async {
  final list = await getPatients();
  final exists = list.any((e) => _identity(e) == _identity(p));
  if (!exists) {
    list.add(p);
    await savePatients(list);
  }
}


  // LOGOUT: wipe everything
  Future<void> logout() async {
    final sp = await _prefs;
    await sp.clear();
  }
}
