import 'product.dart';

enum ScanMode { fridgeScan, rescueBasket }

class ScannedProduct {
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
  final int daysToExpiry;
  final ScanMode mode;
  final bool isTemporary;

  const ScannedProduct({
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
    this.daysToExpiry = 7,
    this.mode = ScanMode.fridgeScan,
    this.isTemporary = true,
  });

  factory ScannedProduct.fromProduct(
    ProductInfo product, {
    ScanMode mode = ScanMode.fridgeScan,
    int daysToExpiry = 7,
    bool isTemporary = true,
  }) {
    return ScannedProduct(
      barcode: product.barcode,
      productName: product.productName,
      brand: product.brand,
      genericIngredient: product.genericIngredient,
      allergens: product.allergens,
      nutriScore: product.nutriScore,
      nutritionScore: product.nutritionScore,
      kcal: product.kcal,
      sugar: product.sugar,
      fat: product.fat,
      protein: product.protein,
      salt: product.salt,
      daysToExpiry: daysToExpiry,
      mode: mode,
      isTemporary: isTemporary,
    );
  }

  String get displayIngredient => genericIngredient ?? productName ?? barcode;

  ScannedProduct copyWith({
    int? daysToExpiry,
    ScanMode? mode,
    bool? isTemporary,
  }) {
    return ScannedProduct(
      barcode: barcode,
      productName: productName,
      brand: brand,
      genericIngredient: genericIngredient,
      allergens: allergens,
      nutriScore: nutriScore,
      nutritionScore: nutritionScore,
      kcal: kcal,
      sugar: sugar,
      fat: fat,
      protein: protein,
      salt: salt,
      daysToExpiry: daysToExpiry ?? this.daysToExpiry,
      mode: mode ?? this.mode,
      isTemporary: isTemporary ?? this.isTemporary,
    );
  }

  Map<String, dynamic> toRescueRequest() => {
        'barcode': barcode,
        'generic_ingredient_name': displayIngredient,
        'product_name': productName,
        'brand': brand,
        'allergens': allergens,
        'nutrition_score': nutritionScore,
        'days_to_expiry': daysToExpiry,
        'use_current_fridge': true,
        'mood': 'quick',
        'use_expiry': true,
        'use_context': false,
        'k': 10,
        'model': 'hybrid',
      };

  Map<String, dynamic> toFridgeBody({String? quantity, String? unit}) => {
        'ingredient_name': displayIngredient,
        if (quantity != null && quantity.isNotEmpty) 'quantity': quantity,
        if (unit != null && unit.isNotEmpty) 'unit': unit,
        'days_to_expiry': daysToExpiry,
        'barcode': barcode,
      };

  Map<String, dynamic> toBasketBody() => {
        'barcode': barcode,
        'product_name': productName,
        'brand': brand,
        'generic_ingredient_name': displayIngredient,
        'days_to_expiry': daysToExpiry,
        'allergens': allergens,
        'nutrition_score': nutritionScore,
      };

  ProductInfo toProductInfo() => ProductInfo(
        barcode: barcode,
        productName: productName,
        brand: brand,
        genericIngredient: genericIngredient,
        allergens: allergens,
        nutriScore: nutriScore,
        nutritionScore: nutritionScore,
        kcal: kcal,
        sugar: sugar,
        fat: fat,
        protein: protein,
        salt: salt,
      );
}
