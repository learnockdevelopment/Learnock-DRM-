import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:safe_device/safe_device.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:learnock_drm/screens/splash_screen.dart';
import 'package:learnock_drm/screens/onboarding_screen.dart';
import 'package:learnock_drm/screens/dashboard_screen.dart';
import 'package:learnock_drm/screens/material_viewer_screen.dart';
import 'package:learnock_drm/screens/course_detail_screen.dart';
import 'package:learnock_drm/screens/profile_screen.dart';
import 'package:learnock_drm/screens/faqs_screen.dart';
import 'package:learnock_drm/screens/courses_screen.dart';
import 'package:learnock_drm/screens/highlights_screen.dart';
import 'package:learnock_drm/screens/subscribe_screen.dart';
import 'package:learnock_drm/screens/favorites_screen.dart';
import 'package:learnock_drm/screens/transactions_screen.dart';
import 'package:learnock_drm/screens/wallet_screen.dart';
import 'package:learnock_drm/providers/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await NoScreenshot.instance.screenshotOff();
  } catch (e) {
    debugPrint('Security Error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const DerasyApp(),
    ),
  );
}

class DerasyApp extends StatelessWidget {
  const DerasyApp({super.key}); 

  @override
  Widget build(BuildContext context) {
    return Consumer2<LanguageProvider, ThemeProvider>(
      builder: (context, lang, theme, child) {
        return MaterialApp(
          title: 'Learnock Player',
          debugShowCheckedModeBanner: false,
          locale: lang.currentLocale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [ 
            Locale('en'),
            Locale('ar'),
          ],
          theme: theme.themeData.copyWith(
            textTheme: GoogleFonts.rubikTextTheme(theme.themeData.textTheme),
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/faqs': (context) => const FaqsScreen(),
            '/all-courses': (context) => const CoursesScreen(),
            '/favorites': (context) => const FavoritesScreen(),
            '/transactions': (context) => const TransactionsScreen(),
            '/highlights': (context) => const HighlightsScreen(),
            '/subscribe': (context) {
              final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return SubscribeScreen(course: args ?? {});
            },
            '/wallet': (context) => const WalletScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/course') {
              final id = settings.arguments as int;
              return MaterialPageRoute(builder: (context) => CourseDetailScreen(courseId: id));
            }
            if (settings.name == '/material') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(builder: (context) => MaterialViewerScreen(
                material: args['material'], 
                courseId: args['courseId'],
                forceLandscape: args['forceLandscape'] ?? false,
                nextMaterial: args['nextMaterial'],
              ));
            }
            return null;
          },
        );
      },
    );
  }
}
