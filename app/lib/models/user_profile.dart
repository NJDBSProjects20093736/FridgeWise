class UserProfile {
  final int userId;
  final String dietaryType;
  final List<String> allergies;
  final List<String> nutritionPrefs;
  final List<String> preferredCuisines;
  final double opennessToNewCuisines;
  final String mood;

  // High-value personalisation (ThriftyChef differentiators)
  final double foodWastePriority; // 0 = variety, 1 = reduce waste
  final String cookingSkill; // beginner | intermediate | advanced
  final int maxCookMinutes; // 0 = no limit
  final List<String> mealTypes;
  final String budget; // budget | normal | premium
  final List<String> kitchenEquipment;
  final List<String> healthGoals;
  final List<String> likedIngredients;
  final List<String> dislikedIngredients;
  final String shoppingPreference; // fridge_only | minimal | shopping_ok
  final String leftoverPreference; // love | occasionally | fresh_only
  final double spiceLevel; // 0 mild → 1 extra hot
  final String servings; // 1 | 2 | 4 | 6+ | family
  final List<String> cookingMethods;
  final List<String> sustainabilityPrefs;
  final List<String> favouriteCategories;
  final double aiSurprise; // 0 safe → 1 surprise

  const UserProfile({
    this.userId = 5060,
    this.dietaryType = 'none',
    this.allergies = const [],
    this.nutritionPrefs = const [],
    this.preferredCuisines = const [],
    this.opennessToNewCuisines = 0.5,
    this.mood = 'comfort',
    this.foodWastePriority = 0.7,
    this.cookingSkill = 'intermediate',
    this.maxCookMinutes = 0, // session filter; 0 = no limit
    this.mealTypes = const [],
    this.budget = 'normal',
    this.kitchenEquipment = const [],
    this.healthGoals = const [],
    this.likedIngredients = const [],
    this.dislikedIngredients = const [],
    this.shoppingPreference = 'minimal',
    this.leftoverPreference = 'occasionally',
    this.spiceLevel = 0.35,
    this.servings = '2',
    this.cookingMethods = const [],
    this.sustainabilityPrefs = const [],
    this.favouriteCategories = const [],
    this.aiSurprise = 0.4,
  });

  static const dietOptions = {
    'none': 'None',
    'vegetarian': 'Vegetarian',
    'vegan': 'Vegan',
    'halal': 'Halal',
    'pescatarian': 'Pescatarian',
    'flexitarian': 'Flexitarian',
    'keto': 'Keto',
    'paleo': 'Paleo',
    'mediterranean': 'Mediterranean',
    'dairy_free': 'Dairy free',
    'gluten_free': 'Gluten free',
    'kosher': 'Kosher',
    'jain': 'Jain',
    'low_carb': 'Low carb',
    'whole30': 'Whole30',
  };

  static const allergyOptions = [
    'milk',
    'eggs',
    'peanuts',
    'tree-nuts',
    'gluten',
    'soy',
    'fish',
    'shellfish',
    'sesame',
    'mustard',
    'celery',
    'lupin',
    'sulphites',
    'molluscs',
    'lactose',
    'fructose',
  ];

  static const allergyLabels = {
    'milk': 'Milk',
    'eggs': 'Eggs',
    'peanuts': 'Peanuts',
    'tree-nuts': 'Tree nuts',
    'gluten': 'Gluten',
    'soy': 'Soy',
    'fish': 'Fish',
    'shellfish': 'Shellfish',
    'sesame': 'Sesame',
    'mustard': 'Mustard',
    'celery': 'Celery',
    'lupin': 'Lupin',
    'sulphites': 'Sulphites',
    'molluscs': 'Molluscs',
    'lactose': 'Lactose intolerance',
    'fructose': 'Fructose intolerance',
  };

  static const nutritionOptions = {
    'low_sugar': 'Low sugar',
    'low_fat': 'Low fat',
    'gluten_free': 'Gluten free',
    'high_protein': 'High protein',
    'low_sodium': 'Low sodium',
    'low_carb': 'Low carb',
    'high_fibre': 'High fibre',
    'heart_healthy': 'Heart healthy',
    'diabetic_friendly': 'Diabetic friendly',
    'low_cholesterol': 'Low cholesterol',
    'high_iron': 'High iron',
    'omega_3': 'Omega-3 rich',
  };

  static const cuisineOptions = [
    'Italian',
    'Asian',
    'Indian',
    'Mexican',
    'Mediterranean',
    'Sri Lankan',
    'Chinese',
    'Japanese',
    'Korean',
    'Thai',
    'Vietnamese',
    'French',
    'Spanish',
    'Greek',
    'Middle Eastern',
    'American',
    'Irish',
    'Caribbean',
    'Any',
  ];

  static const moodOptions = ['comfort', 'healthy', 'quick', 'adventurous', 'celebration'];

  static const cookingSkillOptions = {
    'beginner': 'Beginner',
    'intermediate': 'Intermediate',
    'advanced': 'Advanced',
  };

  static const cookTimeOptions = {
    10: 'Under 10 min',
    20: 'Under 20 min',
    30: 'Under 30 min',
    45: 'Under 45 min',
    0: 'No limit',
  };

  static const mealTypeOptions = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Dessert', 'Drinks'];

  static const budgetOptions = {
    'budget': 'Budget',
    'normal': 'Normal',
    'premium': 'Premium',
  };

  static const equipmentOptions = [
    'Blender',
    'Air Fryer',
    'Rice Cooker',
    'Pressure Cooker',
    'Food Processor',
    'BBQ',
    'Oven',
    'Microwave',
  ];

  static const healthGoalOptions = [
    'Lose Weight',
    'Maintain Weight',
    'Gain Muscle',
    'Eat More Vegetables',
    'Lower Sugar',
    'Lower Salt',
    'High Energy Meals',
    'Heart Healthy',
  ];

  static const loveIngredientOptions = [
    'mushrooms',
    'cheese',
    'garlic',
    'chicken',
    'tomatoes',
    'spinach',
    'eggs',
    'potato',
    'rice',
    'pasta',
  ];

  static const avoidIngredientOptions = [
    'olives',
    'coriander',
    'mushrooms',
    'coconut',
    'tofu',
    'broccoli',
    'anchovy',
    'blue cheese',
  ];

  static const shoppingPreferenceOptions = {
    'fridge_only': 'Use only fridge items',
    'minimal': 'Prefer minimal shopping',
    'shopping_ok': 'Shopping is okay',
  };

  static const leftoverPreferenceOptions = {
    'love': 'Love leftovers',
    'occasionally': 'Occasionally',
    'fresh_only': 'Fresh meals only',
  };

  static const servingsOptions = ['1', '2', '4', '6+', 'family'];

  static const cookingMethodOptions = [
    'Air Fryer',
    'Oven',
    'Stovetop',
    'Microwave',
    'Pressure Cooker',
    'Slow Cooker',
    'Grill',
    'No Preference',
  ];

  static const sustainabilityOptions = [
    'Local ingredients',
    'Seasonal ingredients',
    'Low carbon meals',
    'Plant-forward',
    'Reduce packaging',
  ];

  static const favouriteCategoryOptions = [
    'Pasta',
    'Rice',
    'Curry',
    'Soup',
    'Salad',
    'Stir Fry',
    'Sandwich',
    'Pizza',
    'Burgers',
    'Wraps',
    'Noodles',
  ];

  UserProfile copyWith({
    String? dietaryType,
    List<String>? allergies,
    List<String>? nutritionPrefs,
    List<String>? preferredCuisines,
    double? opennessToNewCuisines,
    String? mood,
    double? foodWastePriority,
    String? cookingSkill,
    int? maxCookMinutes,
    List<String>? mealTypes,
    String? budget,
    List<String>? kitchenEquipment,
    List<String>? healthGoals,
    List<String>? likedIngredients,
    List<String>? dislikedIngredients,
    String? shoppingPreference,
    String? leftoverPreference,
    double? spiceLevel,
    String? servings,
    List<String>? cookingMethods,
    List<String>? sustainabilityPrefs,
    List<String>? favouriteCategories,
    double? aiSurprise,
  }) {
    return UserProfile(
      userId: userId,
      dietaryType: dietaryType ?? this.dietaryType,
      allergies: allergies ?? this.allergies,
      nutritionPrefs: nutritionPrefs ?? this.nutritionPrefs,
      preferredCuisines: preferredCuisines ?? this.preferredCuisines,
      opennessToNewCuisines: opennessToNewCuisines ?? this.opennessToNewCuisines,
      mood: mood ?? this.mood,
      foodWastePriority: foodWastePriority ?? this.foodWastePriority,
      cookingSkill: cookingSkill ?? this.cookingSkill,
      maxCookMinutes: maxCookMinutes ?? this.maxCookMinutes,
      mealTypes: mealTypes ?? this.mealTypes,
      budget: budget ?? this.budget,
      kitchenEquipment: kitchenEquipment ?? this.kitchenEquipment,
      healthGoals: healthGoals ?? this.healthGoals,
      likedIngredients: likedIngredients ?? this.likedIngredients,
      dislikedIngredients: dislikedIngredients ?? this.dislikedIngredients,
      shoppingPreference: shoppingPreference ?? this.shoppingPreference,
      leftoverPreference: leftoverPreference ?? this.leftoverPreference,
      spiceLevel: spiceLevel ?? this.spiceLevel,
      servings: servings ?? this.servings,
      cookingMethods: cookingMethods ?? this.cookingMethods,
      sustainabilityPrefs: sustainabilityPrefs ?? this.sustainabilityPrefs,
      favouriteCategories: favouriteCategories ?? this.favouriteCategories,
      aiSurprise: aiSurprise ?? this.aiSurprise,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as int? ?? 5060,
      dietaryType: json['dietary_type'] as String? ?? 'none',
      allergies: _stringList(json['allergies']),
      nutritionPrefs: _stringList(json['nutrition_prefs']),
      preferredCuisines: _stringList(json['preferred_cuisines']),
      opennessToNewCuisines: (json['openness_to_new_cuisines'] as num?)?.toDouble() ?? 0.5,
      mood: json['mood'] as String? ?? 'comfort',
      foodWastePriority: (json['food_waste_priority'] as num?)?.toDouble() ?? 0.7,
      cookingSkill: json['cooking_skill'] as String? ?? 'intermediate',
      maxCookMinutes: (json['max_cook_minutes'] as num?)?.toInt() ?? 0,
      mealTypes: _stringList(json['meal_types']),
      budget: json['budget'] as String? ?? 'normal',
      kitchenEquipment: _stringList(json['kitchen_equipment']),
      healthGoals: _stringList(json['health_goals']),
      likedIngredients: _stringList(json['liked_ingredients']),
      dislikedIngredients: _stringList(json['disliked_ingredients']),
      shoppingPreference: json['shopping_preference'] as String? ?? 'minimal',
      leftoverPreference: json['leftover_preference'] as String? ?? 'occasionally',
      spiceLevel: (json['spice_level'] as num?)?.toDouble() ?? 0.35,
      servings: json['servings']?.toString() ?? '2',
      cookingMethods: _stringList(json['cooking_methods']),
      sustainabilityPrefs: _stringList(json['sustainability_prefs']),
      favouriteCategories: _stringList(json['favourite_categories']),
      aiSurprise: (json['ai_surprise'] as num?)?.toDouble() ?? 0.4,
    );
  }

  Map<String, dynamic> toJson() => {
        'dietary_type': dietaryType,
        'allergies': allergies,
        'nutrition_prefs': nutritionPrefs,
        'preferred_cuisines': preferredCuisines,
        'openness_to_new_cuisines': opennessToNewCuisines,
        'mood': mood,
        'food_waste_priority': foodWastePriority,
        'cooking_skill': cookingSkill,
        'max_cook_minutes': maxCookMinutes,
        'meal_types': mealTypes,
        'budget': budget,
        'kitchen_equipment': kitchenEquipment,
        'health_goals': healthGoals,
        'liked_ingredients': likedIngredients,
        'disliked_ingredients': dislikedIngredients,
        'shopping_preference': shoppingPreference,
        'leftover_preference': leftoverPreference,
        'spice_level': spiceLevel,
        'servings': servings,
        'cooking_methods': cookingMethods,
        'sustainability_prefs': sustainabilityPrefs,
        'favourite_categories': favouriteCategories,
        'ai_surprise': aiSurprise,
      };

  String get filterSummary {
    final parts = <String>[];
    if (dietaryType != 'none') parts.add(dietOptions[dietaryType] ?? dietaryType);
    parts.addAll(allergies.take(2));
    for (final p in nutritionPrefs.take(2)) {
      parts.add(nutritionOptions[p] ?? p);
    }
    if (preferredCuisines.isNotEmpty && !preferredCuisines.contains('Any')) {
      parts.addAll(preferredCuisines.take(2));
    }
    if (maxCookMinutes > 0) parts.add('≤$maxCookMinutes min');
    return parts.isEmpty ? 'No filters' : parts.join(' · ');
  }
}
