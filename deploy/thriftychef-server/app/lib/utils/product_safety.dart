import '../models/user_profile.dart';

class ProductSafetyCheck {
  final bool safe;
  final List<String> warnings;

  const ProductSafetyCheck({required this.safe, required this.warnings});

  static const _allergenHints = {
    'milk': ['milk', 'cheese', 'cream', 'butter', 'yogurt', 'whey'],
    'eggs': ['egg'],
    'peanuts': ['peanut'],
    'gluten': ['flour', 'wheat', 'bread', 'pasta', 'gluten'],
    'soy': ['soy', 'tofu', 'tempeh', 'miso'],
    'fish': ['fish', 'salmon', 'tuna', 'cod'],
  };

  static ProductSafetyCheck evaluate({
    required UserProfile profile,
    String? productName,
    String? genericIngredient,
    String? allergens,
  }) {
    final blob = '${productName ?? ''} ${genericIngredient ?? ''} ${allergens ?? ''}'.toLowerCase();
    final generic = (genericIngredient ?? '').toLowerCase();
    final warnings = <String>[];

    for (final allergy in profile.allergies) {
      final hints = _allergenHints[allergy] ?? [allergy];
      for (final hint in hints) {
        if (blob.contains(hint) || generic.contains(hint)) {
          warnings.add('This product may not be safe for your allergy profile ($allergy).');
          break;
        }
      }
    }

    final diet = profile.dietaryType;
    const meat = ['chicken', 'beef', 'pork', 'lamb', 'bacon', 'ham', 'fish'];
    const dairyEgg = ['milk', 'cheese', 'cream', 'butter', 'egg'];

    if (diet == 'vegetarian' && _hits(blob + generic, meat)) {
      warnings.add('Not compatible with your vegetarian diet.');
    }
    if (diet == 'vegan' && _hits(blob + generic, [...meat, ...dairyEgg])) {
      warnings.add('Not compatible with your vegan diet.');
    }
    if (diet == 'halal' && _hits(blob + generic, ['pork', 'bacon', 'ham'])) {
      warnings.add('Not compatible with your halal diet.');
    }

    return ProductSafetyCheck(safe: warnings.isEmpty, warnings: warnings);
  }

  static bool _hits(String text, List<String> keywords) {
    for (final k in keywords) {
      if (text.contains(k)) return true;
    }
    return false;
  }
}
