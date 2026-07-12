class UserProfile {
  final int userId;
  final String dietaryType;
  final List<String> allergies;
  final List<String> nutritionPrefs;
  final List<String> preferredCuisines;
  final double opennessToNewCuisines;
  final String mood;

  const UserProfile({
    this.userId = 5060,
    this.dietaryType = 'none',
    this.allergies = const [],
    this.nutritionPrefs = const [],
    this.preferredCuisines = const [],
    this.opennessToNewCuisines = 0.5,
    this.mood = 'comfort',
  });

  static const dietOptions = ['none', 'vegetarian', 'vegan', 'halal'];
  static const allergyOptions = ['milk', 'eggs', 'peanuts', 'gluten', 'soy', 'fish'];
  static const nutritionOptions = {
    'low_sugar': 'Low sugar',
    'low_fat': 'Low fat',
    'gluten_free': 'Gluten free',
    'high_protein': 'High protein',
  };
  static const cuisineOptions = [
    'Italian',
    'Asian',
    'Indian',
    'Mexican',
    'Mediterranean',
    'Sri Lankan',
    'Any',
  ];
  static const moodOptions = ['comfort', 'healthy', 'quick', 'adventurous', 'celebration'];

  UserProfile copyWith({
    String? dietaryType,
    List<String>? allergies,
    List<String>? nutritionPrefs,
    List<String>? preferredCuisines,
    double? opennessToNewCuisines,
    String? mood,
  }) {
    return UserProfile(
      userId: userId,
      dietaryType: dietaryType ?? this.dietaryType,
      allergies: allergies ?? this.allergies,
      nutritionPrefs: nutritionPrefs ?? this.nutritionPrefs,
      preferredCuisines: preferredCuisines ?? this.preferredCuisines,
      opennessToNewCuisines: opennessToNewCuisines ?? this.opennessToNewCuisines,
      mood: mood ?? this.mood,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as int? ?? 5060,
      dietaryType: json['dietary_type'] as String? ?? 'none',
      allergies: (json['allergies'] as List<dynamic>? ?? []).cast<String>(),
      nutritionPrefs: (json['nutrition_prefs'] as List<dynamic>? ?? []).cast<String>(),
      preferredCuisines: (json['preferred_cuisines'] as List<dynamic>? ?? []).cast<String>(),
      opennessToNewCuisines: (json['openness_to_new_cuisines'] as num?)?.toDouble() ?? 0.5,
      mood: json['mood'] as String? ?? 'comfort',
    );
  }

  Map<String, dynamic> toJson() => {
        'dietary_type': dietaryType,
        'allergies': allergies,
        'nutrition_prefs': nutritionPrefs,
        'preferred_cuisines': preferredCuisines,
        'openness_to_new_cuisines': opennessToNewCuisines,
        'mood': mood,
      };

  String get filterSummary {
    final parts = <String>[];
    if (dietaryType != 'none') parts.add(dietaryType);
    parts.addAll(allergies);
    for (final p in nutritionPrefs) {
      parts.add(nutritionOptions[p] ?? p);
    }
    if (preferredCuisines.isNotEmpty && !preferredCuisines.contains('Any')) {
      parts.addAll(preferredCuisines.take(2));
    }
    return parts.isEmpty ? 'No filters' : parts.join(' · ');
  }
}
