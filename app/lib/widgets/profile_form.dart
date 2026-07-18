import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'chip_selectors.dart';
import 'section_card.dart';

class ProfileFormContent extends StatelessWidget {
  final UserProfile draft;
  final ValueChanged<UserProfile> onChanged;

  const ProfileFormContent({super.key, required this.draft, required this.onChanged});

  void _toggleList(List<String> current, String value, ValueChanged<List<String>> save) {
    final list = List<String>.from(current);
    list.contains(value) ? list.remove(value) : list.add(value);
    save(list);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'A. Dietary requirement',
          helper: 'Hard safety filter for recipe recommendations.',
          child: _SingleChoiceWrap(
            options: UserProfile.dietOptions,
            selected: draft.dietaryType,
            onChanged: (d) => onChanged(draft.copyWith(dietaryType: d)),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'B. Allergies & intolerances',
          helper: 'Used as hard safety filters.',
          child: ProfileChipSelector(
            options: UserProfile.allergyOptions,
            selected: draft.allergies.toSet(),
            labelBuilder: (a) => UserProfile.allergyLabels[a] ?? a,
            onToggle: (a) => _toggleList(draft.allergies, a, (list) => onChanged(draft.copyWith(allergies: list))),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'C. Nutrition preferences',
          child: ProfileChipSelector(
            options: UserProfile.nutritionOptions.keys.toList(),
            selected: draft.nutritionPrefs.toSet(),
            labelBuilder: (k) => UserProfile.nutritionOptions[k] ?? k,
            onToggle: (key) => _toggleList(
              draft.nutritionPrefs,
              key,
              (list) => onChanged(draft.copyWith(nutritionPrefs: list)),
            ),
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
          title: 'E. Food waste priority',
          helper: 'Core ThriftyChef setting — higher values prioritise expiring ingredients.',
          child: _LabeledSlider(
            value: draft.foodWastePriority,
            left: 'Recipe variety',
            right: 'Reduce waste',
            onChanged: (v) => onChanged(draft.copyWith(foodWastePriority: v)),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'F. Cooking skill',
          child: _SingleChoiceWrap(
            options: UserProfile.cookingSkillOptions,
            selected: draft.cookingSkill,
            onChanged: (v) => onChanged(draft.copyWith(cookingSkill: v)),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'G. Budget',
          child: _SingleChoiceWrap(
            options: UserProfile.budgetOptions,
            selected: draft.budget,
            onChanged: (v) => onChanged(draft.copyWith(budget: v)),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'H. Servings',
          child: _SingleChoiceWrap(
            options: {for (final s in UserProfile.servingsOptions) s: s == 'family' ? 'Family size' : s},
            selected: draft.servings,
            onChanged: (v) => onChanged(draft.copyWith(servings: v)),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'I. Health goals',
          child: ProfileChipSelector(
            options: UserProfile.healthGoalOptions,
            selected: draft.healthGoals.toSet(),
            onToggle: (v) => _toggleList(draft.healthGoals, v, (list) => onChanged(draft.copyWith(healthGoals: list))),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'J. Ingredients you love',
          helper: 'Recipes with these ingredients rank higher.',
          child: ProfileChipSelector(
            options: UserProfile.loveIngredientOptions,
            selected: draft.likedIngredients.toSet(),
            onToggle: (v) => _toggleList(
              draft.likedIngredients,
              v,
              (list) => onChanged(draft.copyWith(likedIngredients: list)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'K. Ingredients to avoid',
          helper: 'Recipes with these are filtered or ranked lower.',
          child: ProfileChipSelector(
            options: UserProfile.avoidIngredientOptions,
            selected: draft.dislikedIngredients.toSet(),
            onToggle: (v) => _toggleList(
              draft.dislikedIngredients,
              v,
              (list) => onChanged(draft.copyWith(dislikedIngredients: list)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'L. Shopping preference',
          child: _SingleChoiceWrap(
            options: UserProfile.shoppingPreferenceOptions,
            selected: draft.shoppingPreference,
            onChanged: (v) => onChanged(draft.copyWith(shoppingPreference: v)),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'M. Leftover preference',
          helper: 'Helps leftover generator and batch-cooking suggestions.',
          child: _SingleChoiceWrap(
            options: UserProfile.leftoverPreferenceOptions,
            selected: draft.leftoverPreference,
            onChanged: (v) => onChanged(draft.copyWith(leftoverPreference: v)),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'N. Kitchen equipment',
          child: ProfileChipSelector(
            options: UserProfile.equipmentOptions,
            selected: draft.kitchenEquipment.toSet(),
            onToggle: (v) => _toggleList(
              draft.kitchenEquipment,
              v,
              (list) => onChanged(draft.copyWith(kitchenEquipment: list)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'O. Preferred cooking methods',
          child: ProfileChipSelector(
            options: UserProfile.cookingMethodOptions,
            selected: draft.cookingMethods.toSet(),
            onToggle: (v) {
              if (v == 'No Preference') {
                onChanged(draft.copyWith(cookingMethods: draft.cookingMethods.contains(v) ? [] : [v]));
                return;
              }
              final list = List<String>.from(draft.cookingMethods)..remove('No Preference');
              list.contains(v) ? list.remove(v) : list.add(v);
              onChanged(draft.copyWith(cookingMethods: list));
            },
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'P. Favourite meal categories',
          child: ProfileChipSelector(
            options: UserProfile.favouriteCategoryOptions,
            selected: draft.favouriteCategories.toSet(),
            onToggle: (v) => _toggleList(
              draft.favouriteCategories,
              v,
              (list) => onChanged(draft.copyWith(favouriteCategories: list)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Q. Sustainability',
          child: ProfileChipSelector(
            options: UserProfile.sustainabilityOptions,
            selected: draft.sustainabilityPrefs.toSet(),
            onToggle: (v) => _toggleList(
              draft.sustainabilityPrefs,
              v,
              (list) => onChanged(draft.copyWith(sustainabilityPrefs: list)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'R. Spice level',
          child: _LabeledSlider(
            value: draft.spiceLevel,
            left: 'Mild',
            right: 'Extra hot',
            onChanged: (v) => onChanged(draft.copyWith(spiceLevel: v)),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'S. Openness to new cuisines',
          child: _LabeledSlider(
            value: draft.opennessToNewCuisines,
            left: 'Familiar only',
            right: 'Adventurous',
            onChanged: (v) => onChanged(draft.copyWith(opennessToNewCuisines: v)),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'T. Openness to AI suggestions',
          helper: 'Safer familiar picks vs more surprising suggestions.',
          child: _LabeledSlider(
            value: draft.aiSurprise,
            left: 'Safe recipes',
            right: 'Surprise me',
            onChanged: (v) => onChanged(draft.copyWith(aiSurprise: v)),
          ),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final double value;
  final String left;
  final String right;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.value,
    required this.left,
    required this.right,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: value.clamp(0, 1),
          min: 0,
          max: 1,
          divisions: 10,
          activeColor: AppTheme.primaryGreen,
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(left, style: Theme.of(context).textTheme.bodySmall),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
            ),
            Text(right, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _SingleChoiceWrap extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _SingleChoiceWrap({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.entries.map((e) {
        final isSelected = selected == e.key;
        return InkWell(
          onTap: () => onChanged(e.key),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minWidth: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.lightGreen : AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.primaryGreen : AppTheme.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  e.value,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
