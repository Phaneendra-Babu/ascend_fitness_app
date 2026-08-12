import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/diet_screen.dart';
import 'screens/todos_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/workouts_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/splash_screen.dart';
import 'controllers/theme_controller.dart';
import 'controllers/progress_controller.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'models/workout_plan.dart';
import 'models/diet_plan.dart';
import 'services/local_storage.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LocalStorage.init();
  // Initialise scheduled-notification reminders (requests the Android 13+
  // notification permission). Safe to call before the user is signed in.
  await NotificationService.instance.init();
  final themeController = ThemeController();
  await themeController.load();
  runApp(AscendApp(themeController: themeController));
}

class AscendApp extends StatefulWidget {
  final ThemeController themeController;
  const AscendApp({super.key, required this.themeController});

  @override
  State<AscendApp> createState() => _AscendAppState();
}

class _AscendAppState extends State<AscendApp> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.themeController,
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          title: 'ASCEND',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          theme: AppTheme.getTheme(theme.currentMode, false),
          darkTheme: AppTheme.getTheme(theme.currentMode, true),
          home: _splashDone
              ? const AuthGate()
              : SplashScreen(onComplete: () => setState(() => _splashDone = true)),
          routes: {
            '/onboarding': (context) => const OnboardingScreen(),
          },
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // userChanges() (not authStateChanges) also fires when the user's
      // emailVerified flag flips, so the gate re-routes the moment a new
      // account verifies their email.
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        // Scope local storage to the signed-in account before any screen
        // reads it, so different accounts on this device keep separate data
        // (workout plan, diet plan, habits, XP, streak, missions).
        LocalStorage.setUserId(snapshot.data?.uid);

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(color: context.accent),
            ),
          );
        }
        if (snapshot.hasData) {
          // Gate unverified accounts: they must confirm their email (via the
          // link Firebase emails them) before onboarding.
          if (!snapshot.data!.emailVerified) {
            return const VerifyEmailScreen();
          }
          // Check if onboarding is completed
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  body: Center(
                    child: CircularProgressIndicator(color: context.accent),
                  ),
                );
              }
              final userData = userSnapshot.data?.data() ?? {};
              final onboardingCompleted = userData['onboardingCompleted'] == true;
              if (onboardingCompleted) {
                return const MainNavigationScreen();
              }
              return const OnboardingScreen();
            },
          );
        }
        return const AuthScreen();
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  // Tabs that have been opened at least once. Home (index 0) is always
  // built; the rest load lazily on first visit so tab screens don't all
  // fetch their data at startup.
  final Set<int> _visitedTabs = {0};

  @override
  void dispose() {
    // This screen is torn down on account switch / logout — drop the old
    // account's pending reminder notifications.
    NotificationService.instance.cancelAll();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _visitedTabs.add(index);
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkoutPlanState()..load()),
        ChangeNotifierProvider(create: (_) => DietPlanState()..load()),
        ChangeNotifierProvider(create: (_) => ProgressController()..load()),
      ],
      child: _MainNavigationBody(
        selectTab: _selectTab,
        currentIndex: _currentIndex,
        visitedTabs: _visitedTabs,
      ),
    );
  }
}

class _MainNavigationBody extends StatelessWidget {
  final void Function(int) selectTab;
  final int currentIndex;
  final Set<int> visitedTabs;

  const _MainNavigationBody({
    required this.selectTab,
    required this.currentIndex,
    required this.visitedTabs,
  });

  /// The screen for a tab, or an empty placeholder until that tab is first
  /// opened. Kept inside an `IndexedStack` so each tab's state survives tab
  /// switches without ever building all tabs at once.
  Widget _screenFor(BuildContext context, int index) {
    if (!visitedTabs.contains(index)) return const SizedBox.shrink();
    final planState = Provider.of<WorkoutPlanState>(context);
    switch (index) {
      case 0:
        return HomeScreen(onNavigateToTab: selectTab);
      case 1:
        return const DietScreen();
      case 2:
        return TodosScreen(
          weeklyPlan: planState.plan,
          onPlanChanged: (plan) => planState.updatePlan(plan),
        );
      case 3:
        return const RecipesScreen();
      case 4:
        return const WorkoutsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        // Back on any tab except Home returns to Home; back on Home falls
        // through to the system (the root route) and closes the app.
        if (!didPop && currentIndex != 0) {
          selectTab(0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: [for (var i = 0; i < 5; i++) _screenFor(context, i)],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: context.navBarShadow,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: selectTab,
            backgroundColor: context.navBarBackground,
            indicatorColor: context.accent.withValues(alpha: 0.1),
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: context.textMuted),
                selectedIcon: Icon(Icons.home, color: context.accent),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.restaurant_menu_outlined, color: context.textMuted),
                selectedIcon: Icon(Icons.restaurant_menu, color: context.accent),
                label: 'Diet',
              ),
              NavigationDestination(
                icon: Icon(Icons.check_box_outlined, color: context.textMuted),
                selectedIcon: Icon(Icons.check_box, color: context.accent),
                label: 'Todos',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined, color: context.textMuted),
                selectedIcon: Icon(Icons.menu_book, color: context.accent),
                label: 'Recipes',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined, color: context.textMuted),
                selectedIcon: Icon(Icons.fitness_center, color: context.accent),
                label: 'Workouts',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
