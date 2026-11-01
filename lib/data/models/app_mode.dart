enum AppMode {
  fieldSales('field_sales'),
  yardSales('yard_sales');

  const AppMode(this.id);
  final String id;

  static AppMode fromId(String? id) =>
      AppMode.values.firstWhere((m) => m.id == id, orElse: () => AppMode.fieldSales);

  bool get isCommunity => this != AppMode.fieldSales;
}
