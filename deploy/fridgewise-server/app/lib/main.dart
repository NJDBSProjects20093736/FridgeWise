import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(
    Provider<ApiService>(
      create: (_) => ApiService(),
      child: const FridgeWiseApp(),
    ),
  );
}

class FridgeWiseApp extends StatelessWidget {
  const FridgeWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FridgeWise AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const _BootstrapScreen(),
    );
  }
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  bool? _apiOk;
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _checkApi();
  }

  Future<void> _checkApi() async {
    final api = context.read<ApiService>();
    final ok = await api.healthCheck();
    if (mounted) setState(() => _apiOk = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_apiOk == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_apiOk!) {
      return Scaffold(
        appBar: AppBar(title: const Text('FridgeWise AI')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('API not reachable', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Start the backend:\npython scripts/run_api.py\n\nBase URL: ${ApiConfig.baseUrl}'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _checkApi, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (!_onboarded) {
      return OnboardingScreen(onComplete: () => setState(() => _onboarded = true));
    }
    return const HomeScreen();
  }
}
