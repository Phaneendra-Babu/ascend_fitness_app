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
import 'screens/splash_screen.dart';
import 'controllers/theme_controller.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'models/workout_plan.dart';
import 'models/diet_plan.dart';
import 'services/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LocalStorage.init();
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
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(color: context.accent),
            ),
          );
        }
        if (snapshot.hasData) {
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

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkoutPlanState()..load()),
        ChangeNotifierProvider(create: (_) => DietPlanState()..load()),
      ],
      child: _MainNavigationBody(selectTab: _selectTab, currentIndex: _currentIndex),
    );
  }
}

class _MainNavigationBody extends StatelessWidget {
  final void Function(int) selectTab;
  final int currentIndex;

  const _MainNavigationBody({required this.selectTab, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final planState = Provider.of<WorkoutPlanState>(context);
    final List<Widget> screens = [
      HomeScreen(onNavigateToTab: selectTab),
      const DietScreen(),
      TodosScreen(
        weeklyPlan: planState.plan,
        onPlanChanged: (plan) => planState.updatePlan(plan),
      ),
      const RecipesScreen(),
      WorkoutsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
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
    );
  }
}
