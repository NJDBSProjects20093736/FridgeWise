import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/fridgewise_repository.dart';
import 'services/local_store.dart';
import 'theme/app_theme.dart';
import 'widgets/empty_state.dart';
import 'widgets/loading_state.dart';
import 'widgets/responsive_container.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => FridgeWiseRepository()),
        Provider(create: (_) => LocalStore()),
        ChangeNotifierProvider(
          create: (ctx) => AppState(ctx.read<FridgeWiseRepository>(), ctx.read<LocalStore>()),
        ),
      ],
      child: const FridgeWiseApp(),
    ),
  );
}

class FridgeWiseApp extends StatelessWidget {
  const FridgeWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    AppTheme.syncDarkMode(state.themeMode == 'dark');
    return MaterialApp(
      title: 'FridgeWise AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(Brightness.light),
      darkTheme: AppTheme.buildTheme(Brightness.dark),
      themeMode: state.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
      home: const BootstrapScreen(),
    );
  }
}


class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    AppTheme.syncDarkMode(state.themeMode == 'dark');

    if (!state.bootstrapped) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: LoadingState(message: state.error ?? 'Starting FridgeWise AI…'),
      );
    }

    if (!state.apiOk) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: ResponsiveContainer(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'API not reachable',
                message: 'Start the backend:\npython scripts/run_api.py\n\nBase URL: ${ApiConfig.baseUrl}',
                action: FilledButton.icon(
                  onPressed: () => state.bootstrap(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry connection'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!state.onboarded) {
      return OnboardingScreen(onComplete: () => setState(() {}));
    }

    return const HomeScreen();
  }
}
