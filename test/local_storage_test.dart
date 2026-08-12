import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascend_app/services/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('storage is isolated per account on the same device', () async {
    await LocalStorage.init();

    // Account A saves progress.
    LocalStorage.setUserId('user-A');
    await LocalStorage.saveInt('totalXP', 100);
    await LocalStorage.saveJson('workoutPlan', {'days': {'1': 'A-plan'}});

    // Switch to account B: it must not see A's data.
    LocalStorage.setUserId('user-B');
    expect(LocalStorage.loadInt('totalXP', 0), 0,
        reason: 'B must start from 0 XP, not inherit A\'s');
    expect(LocalStorage.loadJsonString('workoutPlan'), isNull,
        reason: 'B must not see A\'s workout plan');

    // B saves its own data.
    await LocalStorage.saveInt('totalXP', 250);
    await LocalStorage.saveJson('workoutPlan', {'days': {'2': 'B-plan'}});

    // Switch back to A: A's data is still intact, unaffected by B.
    LocalStorage.setUserId('user-A');
    expect(LocalStorage.loadInt('totalXP', 0), 100);
    expect(LocalStorage.loadJsonString('workoutPlan'),
        contains('A-plan'));

    // Switching back to B again returns B's data.
    LocalStorage.setUserId('user-B');
    expect(LocalStorage.loadInt('totalXP', 0), 250);
    expect(LocalStorage.loadJsonString('workoutPlan'),
        contains('B-plan'));
  });

  test('signed-out (unscoped) storage never leaks into a user scope', () async {
    await LocalStorage.init();

    // Legacy / device-level writes use unscoped keys.
    LocalStorage.setUserId(null);
    await LocalStorage.saveInt('totalXP', 999);

    // A signed-in user must not inherit unscoped data.
    LocalStorage.setUserId('user-A');
    expect(LocalStorage.loadInt('totalXP', 0), 0);
  });
}
