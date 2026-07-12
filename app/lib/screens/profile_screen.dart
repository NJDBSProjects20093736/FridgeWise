import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_form.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserProfile draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    draft = context.read<AppState>().profile;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AppState>().updateProfile(draft);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved — recommendations updated')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Your profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: AppTheme.pagePadding(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTheme.profileMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Update your diet, allergies, and preferences anytime.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 20),
                ProfileFormContent(
                  draft: draft,
                  onChanged: (p) => setState(() => draft = p),
                ),
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
                        : const Text('Save changes'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
