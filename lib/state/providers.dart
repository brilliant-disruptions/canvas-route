import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/alert_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/feature_request_repository.dart';
import '../data/repositories/pin_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/route_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/share_repository.dart';
import '../data/repositories/team_repository.dart';
import '../data/repositories/trip_repository.dart';
import '../data/repositories/visit_repository.dart';
import '../data/services/billing_service.dart';
import '../data/services/directions_service.dart';
import '../data/services/estimate_directions.dart';
import '../data/services/local_prefs.dart';
import '../data/services/location_service.dart';
import '../data/services/nav_launcher.dart';
import '../data/services/places_service.dart';
import '../data/services/reminder_service.dart';
import '../data/services/share_service.dart';
import '../data/services/storage_service.dart';

/// Overridden in main() with the loaded instance.
final localPrefsProvider = Provider<LocalPrefs>((_) => throw UnimplementedError('LocalPrefs not loaded'));

final placesServiceProvider = Provider((_) => PlacesService());
final directionsServiceProvider = Provider<DirectionsService>((_) => FallbackDirectionsService());
final locationServiceProvider = Provider((_) => LocationService());
final storageServiceProvider = Provider((_) => StorageService());
final shareServiceProvider = Provider((_) => ShareService());
final navLauncherProvider = Provider((_) => NavLauncher());
final billingServiceProvider = Provider((_) => BillingService());
final reminderServiceProvider = Provider((_) => ReminderService());

final authRepoProvider = Provider((_) => AuthRepository());
final profileRepoProvider = Provider((_) => ProfileRepository());
final settingsRepoProvider = Provider((_) => SettingsRepository());
final routeRepoProvider = Provider((_) => RouteRepository());
final visitRepoProvider = Provider((_) => VisitRepository());
final pinRepoProvider = Provider((ref) => PinRepository(ref.watch(storageServiceProvider)));
final reportRepoProvider = Provider((_) => ReportRepository());
final productRepoProvider = Provider((_) => ProductRepository());
final featureRequestRepoProvider = Provider((_) => FeatureRequestRepository());
final alertRepoProvider = Provider((_) => AlertRepository());
final shareRepoProvider = Provider((_) => ShareRepository());
final tripRepoProvider = Provider((_) => TripRepository());
final teamRepoProvider = Provider((_) => TeamRepository());
