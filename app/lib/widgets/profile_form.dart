import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'chip_selectors.dart';
import 'section_card.dart';

class ProfileFormContent extends StatelessWidget {
  final UserProfile draft;
  final ValueChanged<UserProfile> onChanged;

  const ProfileFormContent({super.key, required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'A. Dietary requirement',
          helper: 'Used as a hard safety filter for recipe recommendations.',
          child: _DietSelector(
            selected: draft.dietaryType,
            onChanged: (d) => onChanged(draft.copyWith(dietaryType: d)),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'B. Allergies',
          helper: 'Allergies and diet are used as safety filters.',
          child: ProfileChipSelector(
            options: UserProfile.allergyOptions,
            selected: draft.allergies.toSet(),
            onToggle: (a) {
              final list = List<String>.from(draft.allergies);
              list.contains(a) ? list.remove(a) : list.add(a);
              onChanged(draft.copyWith(allergies: list));
            },
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'C. Nutrition preferences',
          child: ProfileChipSelector(
            options: UserProfile.nutritionOptions.keys.toList(),
            selected: draft.nutritionPrefs.toSet(),
            labelBuilder: (k) => UserProfile.nutritionOptions[k] ?? k,
            onToggle: (key) {
              final list = List<String>.from(draft.nutritionPrefs);
              list.contains(key) ? list.remove(key) : list.add(key);
              onChanged(draft.copyWith(nutritionPrefs: list));
            },
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'D. Cuisine preferences',
          child: ProfileChipSelector(
            options: UserProfile.cuisineOptions,
            selected: draft.preferredCuisines.toSet(),
            onToggle: (c) {
              final list = List<String>.from(draft.preferredCuisines);
              if (c == 'Any') {
                onChanged(draft.copyWith(preferredCuisines: list.contains('Any') ? [] : ['Any']));
              } else {
                list.remove('Any');
                list.contains(c) ? list.remove(c) : list.add(c);
                onChanged(draft.copyWith(preferredCuisines: list));
              }
            },
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'E. Openness to new cuisines',
          helper: 'Higher values suggest more adventurous recipe picks.',
          child: Column(
            children: [
              Slider(
                value: draft.opennessToNewCuisines,
                min: 0,
                max: 1,
                divisions: 10,
                activeColor: AppTheme.primaryGreen,
                label: draft.opennessToNewCuisines.toStringAsFixed(1),
                onChanged: (v) => onChanged(draft.copyWith(opennessToNewCuisines: v)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Familiar only', style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    draft.opennessToNewCuisines.toStringAsFixed(1),
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                  ),
                  Text('Adventurous', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DietSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _DietSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: UserProfile.dietOptions.map((d) {
        final isSelected = selected == d;
        final label = d == 'none' ? 'None' : d[0].toUpperCase() + d.substring(1);
        return InkWell(
          onTap: () => onChanged(d),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.lightGreen : AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSelected ? AppTheme.primaryGreen : AppTheme.cardBorder, width: isSelected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: AppTheme.textDark)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
