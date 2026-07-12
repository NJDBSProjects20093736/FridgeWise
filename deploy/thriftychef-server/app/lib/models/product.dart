class ProductInfo {
  final String barcode;
  final String? productName;
  final String? brand;
  final String? genericIngredient;
  final String? allergens;
  final String? nutriScore;
  final double nutritionScore;
  final double? kcal;
  final double? sugar;
  final double? fat;
  final double? protein;
  final double? salt;

  ProductInfo({
    required this.barcode,
    this.productName,
    this.brand,
    this.genericIngredient,
    this.allergens,
    this.nutriScore,
    this.nutritionScore = 0.5,
    this.kcal,
    this.sugar,
    this.fat,
    this.protein,
    this.salt,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      barcode: json['barcode'].toString(),
      productName: json['product_name']?.toString(),
      brand: json['brand']?.toString(),
      genericIngredient: json['generic_ingredient_name']?.toString(),
      allergens: json['allergens']?.toString(),
      nutriScore: json['nutriscore_grade']?.toString(),
      nutritionScore: (json['nutrition_score'] as num?)?.toDouble() ?? 0.5,
      kcal: (json['energy_kcal_100g'] as num?)?.toDouble(),
      sugar: (json['sugars_100g'] as num?)?.toDouble(),
      fat: (json['fat_100g'] as num?)?.toDouble(),
      protein: (json['protein_100g'] as num?)?.toDouble(),
      salt: (json['salt_100g'] as num?)?.toDouble(),
    );
  }
}
