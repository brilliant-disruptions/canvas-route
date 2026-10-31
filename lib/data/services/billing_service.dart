import '../supabase_client.dart';

class BillingException implements Exception {
  BillingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Web billing (Stripe Checkout) for business plans. The create-checkout edge
/// function builds the session; the stripe-webhook function writes the plan back.
class BillingService {
  Future<Uri> checkoutUrl(String product, {int? seats}) async {
    final res = await sb.functions.invoke('create-checkout', body: {'product': product, 'seats': ?seats});
    final data = res.data;
    final url = data is Map ? data['url'] : null;
    if (url is! String) throw BillingException(data is Map && data['error'] is String ? data['error'] as String : 'Checkout is unavailable');
    return Uri.parse(url);
  }
}
