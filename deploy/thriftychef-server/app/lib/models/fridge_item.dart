class FridgeItem {
  final int itemId;
  final String ingredientName;
  final String cleanedName;
  final String? quantity;
  final String? unit;
  final int daysToExpiry;
  final String? barcode;

  FridgeItem({
    required this.itemId,
    required this.ingredientName,
    required this.cleanedName,
    this.quantity,
    this.unit,
    required this.daysToExpiry,
    this.barcode,
  });

  factory FridgeItem.fromJson(Map<String, dynamic> json) {
    return FridgeItem(
      itemId: json['item_id'] as int? ?? json['inventory_id'] as int? ?? 0,
      ingredientName: json['ingredient_name']?.toString() ?? json['cleaned_ingredient_name']?.toString() ?? '',
      cleanedName: json['cleaned_ingredient_name']?.toString() ?? json['ingredient_name']?.toString() ?? '',
      quantity: json['quantity']?.toString(),
      unit: json['unit']?.toString(),
      daysToExpiry: json['days_to_expiry'] as int? ?? 7,
      barcode: json['barcode']?.toString(),
    );
  }

  ColorCategory get urgency {
    if (daysToExpiry <= 2) return ColorCategory.red;
    if (daysToExpiry <= 5) return ColorCategory.amber;
    return ColorCategory.green;
  }
}

enum ColorCategory { red, amber, green }
