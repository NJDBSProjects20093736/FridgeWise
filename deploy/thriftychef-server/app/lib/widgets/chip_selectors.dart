import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoodChipRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const MoodChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = options[i];
          final isSelected = selected == m;
          final label = m[0].toUpperCase() + m.substring(1);
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onSelected(m),
            labelStyle: TextStyle(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            side: BorderSide(color: isSelected ? AppTheme.primaryGreen : AppTheme.cardBorder),
            backgroundColor: AppTheme.cardSurface,
            selectedColor: AppTheme.lightGreen,
          );
        },
      ),
    );
  }
}

class ProfileChipSelector extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String Function(String option)? labelBuilder;

  const ProfileChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return FilterChip(
          label: Text(labelBuilder?.call(opt) ?? _defaultLabel(opt)),
          selected: isSelected,
          onSelected: (_) => onToggle(opt),
          labelStyle: TextStyle(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
          side: BorderSide(color: isSelected ? AppTheme.primaryGreen : AppTheme.cardBorder),
          backgroundColor: AppTheme.cardSurface,
          selectedColor: AppTheme.lightGreen,
        );
      }).toList(),
    );
  }

  String _defaultLabel(String opt) {
    if (opt == 'none') return 'None';
    return opt[0].toUpperCase() + opt.substring(1);
  }
}

class FilterChipRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = selected == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (_) => onSelected(opt),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(color: isSelected ? AppTheme.primaryGreen : AppTheme.cardBorder),
              backgroundColor: AppTheme.cardSurface,
              selectedColor: AppTheme.lightGreen,
            ),
          );
        }).toList(),
      ),
    );
  }
}
