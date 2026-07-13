/// Curated food photo URLs + keyword matching for recipe/ingredient visuals.
class FoodImagery {
  static const _recipes = [
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=640&q=80',
    'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=640&q=80',
    'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=640&q=80',
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=640&q=80',
    'https://images.unsplash.com/photo-1476224203421-9ac39bcb4b2c?auto=format&fit=crop&w=640&q=80',
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=640&q=80',
    'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=640&q=80',
    'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=640&q=80',
    'https://images.unsplash.com/photo-1606787366850-63210686744a?auto=format&fit=crop&w=640&q=80',
    'https://images.unsplash.com/photo-1498837167922-ddd27525cd41?auto=format&fit=crop&w=640&q=80',
    'https://images.unsplash.com/photo-1482049010768-67b54ad25316?auto=format&fit=crop&w=640&q=80',
    'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=640&q=80',
  ];

  static const _ingredientMap = {
    'chicken': 'https://images.unsplash.com/photo-1604503468506-a8da466d78a?auto=format&fit=crop&w=200&q=80',
    'beef': 'https://images.unsplash.com/photo-1603048297170-ab6512675842?auto=format&fit=crop&w=200&q=80',
    'fish': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=200&q=80',
    'salmon': 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=200&q=80',
    'egg': 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3cfc?auto=format&fit=crop&w=200&q=80',
    'milk': 'https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=200&q=80',
    'cheese': 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?auto=format&fit=crop&w=200&q=80',
    'tomato': 'https://images.unsplash.com/photo-1546094096-0df4bcaaa337?auto=format&fit=crop&w=200&q=80',
    'onion': 'https://images.unsplash.com/photo-1518977956812-cd3dbadaaf31?auto=format&fit=crop&w=200&q=80',
    'garlic': 'https://images.unsplash.com/photo-1618375563728-4470d7d4f0ea?auto=format&fit=crop&w=200&q=80',
    'potato': 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=200&q=80',
    'rice': 'https://images.unsplash.com/photo-1536304997881-ef6d1368c476?auto=format&fit=crop&w=200&q=80',
    'pasta': 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9e9?auto=format&fit=crop&w=200&q=80',
    'bread': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=200&q=80',
    'spinach': 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=200&q=80',
    'carrot': 'https://images.unsplash.com/photo-1598170845058-32b9d6d54829?auto=format&fit=crop&w=200&q=80',
    'pepper': 'https://images.unsplash.com/photo-1563565375-3eeba940bfd2?auto=format&fit=crop&w=200&q=80',
    'mushroom': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=200&q=80',
    'lemon': 'https://images.unsplash.com/photo-1587734195503-904fca47e0ae?auto=format&fit=crop&w=200&q=80',
    'butter': 'https://images.unsplash.com/photo-1589985270554-286bfa1072d9?auto=format&fit=crop&w=200&q=80',
    'bean': 'https://images.unsplash.com/photo-1543339494-b4cd4f7d6863?auto=format&fit=crop&w=200&q=80',
    'avocado': 'https://images.unsplash.com/photo-1523049673857-9c5946b50893?auto=format&fit=crop&w=200&q=80',
    'salad': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=200&q=80',
    'soup': 'https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&w=200&q=80',
    'curry': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?auto=format&fit=crop&w=200&q=80',
  };

  static String recipeImageUrl(String name) {
    final lower = name.toLowerCase();
    for (final entry in _ingredientMap.entries) {
      if (lower.contains(entry.key)) return entry.value.replaceAll('w=200', 'w=640');
    }
    return _recipes[name.hashCode.abs() % _recipes.length];
  }

  static String ingredientImageUrl(String name) {
    final lower = name.toLowerCase();
    for (final entry in _ingredientMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return _recipes[name.hashCode.abs() % _recipes.length];
  }

  static List<String> ingredientHints(String recipeName, List<String> fromFridge) {
    if (fromFridge.isNotEmpty) return fromFridge.take(4).toList();
    final lower = recipeName.toLowerCase();
    final hits = <String>[];
    for (final key in _ingredientMap.keys) {
      if (lower.contains(key)) hits.add(key);
    }
    if (hits.isNotEmpty) return hits.take(4).toList();
    return ['fresh', 'herbs', 'veggies'].take(3).toList();
  }
}
