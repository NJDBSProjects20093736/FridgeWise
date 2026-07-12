import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/profile_form.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late UserProfile draft;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    draft = context.read<AppState>().profile;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AppState>().completeOnboarding(draft);
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not save profile. Your choices were saved locally — tap retry to sync with the API.';
          _saving = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: AppTheme.pagePadding(context),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppTheme.profileMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const ThriftyChefLogoHeader(
                  subtitle: 'Personalise your recommendations before we search your fridge.',
                ),
                const SizedBox(height: 32),
                ProfileFormContent(
                  draft: draft,
                  onChanged: (p) => setState(() => draft = p),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: TextStyle(fontSize: 13, color: AppTheme.dangerRed))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save profile and continue'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
