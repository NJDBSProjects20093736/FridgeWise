import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _diet = 'none';
  final Set<String> _allergies = {};

  static const _diets = ['none', 'vegetarian', 'vegan', 'halal'];
  static const _allergyOptions = ['milk', 'eggs', 'peanuts', 'gluten', 'soy', 'fish'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to FridgeWise')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Reduce food waste with smart recipe suggestions', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 24),
          const Text('Dietary preference', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._diets.map((d) => RadioListTile<String>(
                title: Text(d),
                value: d,
                groupValue: _diet,
                onChanged: (v) => setState(() => _diet = v!),
              )),
          const SizedBox(height: 16),
          const Text('Allergies (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: _allergyOptions.map((a) {
              final selected = _allergies.contains(a);
              return FilterChip(
                label: Text(a),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _allergies.add(a);
                  } else {
                    _allergies.remove(a);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: widget.onComplete,
            child: const Text('Continue to my fridge'),
          ),
        ],
      ),
    );
  }
}
