import 'dart:async';

import 'package:flutter/material.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';

class CookingModeScreen extends StatefulWidget {
  final int recipeId;
  final String recipeName;
  final List<String> steps;

  const CookingModeScreen({
    super.key,
    required this.recipeId,
    required this.recipeName,
    required this.steps,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  final _store = LocalStore();
  int _index = 0;
  RecipeProgress _progress = RecipeProgress.empty();
  Timer? _timer;
  int _secondsLeft = 0;
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = await _store.loadRecipeProgress(widget.recipeId);
    if (!mounted) return;
    final firstOpen = progress.steps.isEmpty ? 0 : (progress.steps.toList()..sort()).last + 1;
    setState(() {
      _progress = progress;
      _index = firstOpen.clamp(0, widget.steps.isEmpty ? 0 : widget.steps.length - 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggleCurrent() async {
    final next = Set<int>.from(_progress.steps);
    if (next.contains(_index)) {
      next.remove(_index);
    } else {
      next.add(_index);
    }
    final updated = _progress.copyWith(steps: next);
    setState(() => _progress = updated);
    await _store.saveRecipeProgress(widget.recipeId, updated);
  }

  void _startTimer([int? minutes]) {
    _timer?.cancel();
    final mins = minutes ?? _guessMinutes(widget.steps[_index]);
    setState(() {
      _secondsLeft = mins * 60;
      _timerRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _secondsLeft = 0;
          _timerRunning = false;
        });
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _secondsLeft = 0;
    });
  }

  int _guessMinutes(String step) {
    final match = RegExp(r'(\d+)\s*(minutes?|mins?|min)', caseSensitive: false).firstMatch(step);
    if (match != null) {
      return int.tryParse(match.group(1)!)?.clamp(1, 90) ?? 5;
    }
    return 5;
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cooking mode')),
        body: const Center(child: Text('No steps available for this recipe.')),
      );
    }

    final step = widget.steps[_index];
    final done = _progress.steps.contains(_index);
    final progress = (_progress.steps.length) / widget.steps.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.recipeName, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Padding(
        padding: AppTheme.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step ${_index + 1} of ${widget.steps.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppTheme.iceLight,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: done ? AppTheme.goodTeal : AppTheme.primaryGreen,
                          child: done
                              ? const Icon(Icons.check, color: Colors.white)
                              : Text('${_index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _toggleCurrent,
                          icon: Icon(done ? Icons.check_circle : Icons.circle_outlined),
                          label: Text(done ? 'Done' : 'Mark done'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          step,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                height: 1.4,
                                decoration: done ? TextDecoration.lineThrough : null,
                                color: done ? AppTheme.textMuted : AppTheme.textDark,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.cardDecoration(color: AppTheme.iceLight),
                      child: Column(
                        children: [
                          Text(
                            _timerRunning ? _formatTime(_secondsLeft) : 'Timer',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (!_timerRunning)
                                FilledButton.icon(
                                  onPressed: () => _startTimer(),
                                  icon: const Icon(Icons.timer_outlined),
                                  label: Text('Start ${_guessMinutes(step)} min'),
                                )
                              else
                                OutlinedButton.icon(
                                  onPressed: _stopTimer,
                                  icon: const Icon(Icons.stop),
                                  label: const Text('Stop'),
                                ),
                              TextButton(onPressed: () => _startTimer(1), child: const Text('1 min')),
                              TextButton(onPressed: () => _startTimer(5), child: const Text('5 min')),
                              TextButton(onPressed: () => _startTimer(10), child: const Text('10 min')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _index == 0 ? null : () => setState(() => _index -= 1),
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _index >= widget.steps.length - 1
                        ? () => Navigator.pop(context)
                        : () async {
                            if (!_progress.steps.contains(_index)) await _toggleCurrent();
                            setState(() => _index += 1);
                            _stopTimer();
                          },
                    child: Text(_index >= widget.steps.length - 1 ? 'Finish' : 'Next step'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
