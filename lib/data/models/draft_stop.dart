import 'business.dart';

/// A stop in the unsaved draft route on the Map screen / Builder.
class DraftStop {
  const DraftStop({required this.id, required this.business});

  final String id;
  final Business business;

  DraftStop copyWith({Business? business}) => DraftStop(id: id, business: business ?? this.business);

  Map<String, dynamic> toJson() => {'id': id, 'business': business.toJson()};
  factory DraftStop.fromJson(Map<String, dynamic> j) =>
      DraftStop(id: j['id'] as String, business: Business.fromJson(Map<String, dynamic>.from(j['business'] as Map)));
}
