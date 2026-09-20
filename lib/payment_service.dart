import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  static const String subId = 'bizbox_monthly_99';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  void listenPurchases({void Function(bool success)? onResult}) {
    _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      (List<PurchaseDetails> purchases) async {
        for (final pur in purchases) {
          switch (pur.status) {
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              if (pur.productID == subId) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('is_paid', true);
                await prefs.setString(
                  'purchase_token',
                  pur.verificationData.serverVerificationData,
                );
                await prefs.setString(
                  'payment_date',
                  DateTime.now().toIso8601String(),
                );
                await prefs.setString(
                  'first_open',
                  DateTime.now().toIso8601String(),
                );
                if (pur.pendingCompletePurchase) {
                  await _iap.completePurchase(pur);
                }
                onResult?.call(true);
              }
              break;
            case PurchaseStatus.error:
            case PurchaseStatus.canceled:
              onResult?.call(false);
              break;
            case PurchaseStatus.pending:
              break;
          }
        }
      },
      onError: (_) => onResult?.call(false),
    );
  }

  Future<bool> isPaid() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('is_paid') ?? false;
  }

  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  Future<bool> buy() async {
    final available = await _iap.isAvailable();
    if (!available) return false;
    final resp = await _iap.queryProductDetails({subId});
    if (resp.productDetails.isEmpty) return false;
    final product = resp.productDetails.first;
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
