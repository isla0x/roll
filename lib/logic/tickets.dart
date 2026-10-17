import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 구매 한 번에 들어오는 "바로 현상" 횟수 (롤 1개 = 1회).
const int ticketsPerPack = 5;

/// 스토어에 등록할 소모성 상품 id.
const String ticketProductId = 'com.isla0x.roll.develop5';

/// "바로 현상" 티켓. 5회 2,200원 (실제 가격은 스토어 상품에서 정한다).
class Tickets extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  ProductDetails? product;
  bool storeReady = false;
  bool purchasing = false;
  String? error;

  /// 스토어에서 가져온 가격 (없으면 기본 문구)
  String get priceLabel => product?.price ?? '₩2,200';

  SharedPreferences? _prefs;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _count = _prefs!.getInt('tickets') ?? 0;
    try {
      final iap = InAppPurchase.instance;
      _sub = iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
        error = '$e';
        purchasing = false;
        notifyListeners();
      });
      storeReady = await iap.isAvailable();
      if (storeReady) {
        final res = await iap.queryProductDetails({ticketProductId});
        if (res.productDetails.isNotEmpty) product = res.productDetails.first;
      }
    } catch (e) {
      debugPrint('store init failed: $e');
    }
    notifyListeners();
  }

  Future<void> _set(int v) async {
    _count = v;
    await _prefs?.setInt('tickets', v);
    notifyListeners();
  }

  /// 티켓 1장을 쓴다. 없으면 false.
  Future<bool> use() async {
    if (_count <= 0) return false;
    await _set(_count - 1);
    return true;
  }

  /// 스토어 결제를 시작한다.
  Future<void> buy() async {
    final p = product;
    if (p == null) {
      error = '지금은 스토어에 연결할 수 없어요. 잠시 뒤에 다시 해 주세요.';
      notifyListeners();
      return;
    }
    error = null;
    purchasing = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.buyConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (e) {
      purchasing = false;
      error = '결제를 시작하지 못했어요.';
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != ticketProductId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
          await _set(_count + ticketsPerPack);
          purchasing = false;
        case PurchaseStatus.error:
          error = '결제가 되지 않았어요.';
          purchasing = false;
        case PurchaseStatus.canceled:
          purchasing = false;
        case PurchaseStatus.pending:
        case PurchaseStatus.restored:
          break;
      }
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
