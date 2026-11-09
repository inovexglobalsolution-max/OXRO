import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Live delivery-partner tracking — coordinates, assignment, ETA,
/// instructions, and the OXRO arrival guarantee. All fields optional:
/// the UI renders gracefully from whatever the backend provides.
class LiveTracking {
  const LiveTracking({
    required this.status,
    required this.estimatedArrivalMinutes,
    this.etaLabel,
    this.partnerName,
    this.partnerPhone,
    this.partnerPhotoUrl,
    this.partnerRating,
    this.partnerCompletedDeliveries,
    this.partnerVehicleType,
    this.partnerVehicleNumber,
    this.partnerVerified = true,
    this.partnerLat,
    this.partnerLng,
    this.partnerUpdatedAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.deliveryInstructions,
    this.customerLat,
    this.customerLng,
    this.restaurantId,
    this.restaurantName,
    this.cutleryOptIn,
    this.guaranteeEligible = false,
    this.guaranteeText,
  });

  final String status;
  final int estimatedArrivalMinutes;
  final String? etaLabel;

  final String? partnerName;
  final String? partnerPhone;
  final String? partnerPhotoUrl;
  final double? partnerRating;
  final int? partnerCompletedDeliveries;
  final String? partnerVehicleType;
  final String? partnerVehicleNumber;
  final bool partnerVerified;

  final double? partnerLat;
  final double? partnerLng;
  final String? partnerUpdatedAt;

  final String? assignedAt;
  final String? pickedUpAt;
  final String? deliveredAt;

  final String? deliveryInstructions;

  final double? customerLat;
  final double? customerLng;

  final String? restaurantId;
  final String? restaurantName;
  final bool? cutleryOptIn;

  final bool guaranteeEligible;
  final String? guaranteeText;

  bool get hasPartner => partnerName != null && partnerName!.trim().isNotEmpty;
  bool get hasPartnerLocation => partnerLat != null && partnerLng != null;
  bool get hasCustomerLocation => customerLat != null && customerLng != null;

  factory LiveTracking.fromJson(Map<String, dynamic> m) {
    double? toDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? toInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final partner = m['partner'];
    final pLoc = m['partnerLocation'];
    final coords = m['customerCoordinates'];
    final guarantee = m['guarantee'];
    return LiveTracking(
      status: (m['status'] as String?) ?? 'unknown',
      estimatedArrivalMinutes: toInt(m['estimatedArrivalMinutes']) ?? 0,
      etaLabel: m['etaLabel'] as String?,
      partnerName: partner is Map ? partner['name'] as String? : null,
      partnerPhone: partner is Map ? partner['phone'] as String? : null,
      partnerPhotoUrl: partner is Map ? partner['photoUrl'] as String? : null,
      partnerRating: partner is Map ? toDouble(partner['rating']) : null,
      partnerCompletedDeliveries: partner is Map
          ? toInt(partner['completedDeliveries'])
          : null,
      partnerVehicleType: partner is Map
          ? partner['vehicleType'] as String?
          : null,
      partnerVehicleNumber: partner is Map
          ? partner['vehicleNumber'] as String?
          : null,
      partnerVerified: partner is Map
          ? (partner['verified'] as bool? ?? true)
          : true,
      partnerLat: pLoc is Map ? toDouble(pLoc['latitude']) : null,
      partnerLng: pLoc is Map ? toDouble(pLoc['longitude']) : null,
      partnerUpdatedAt: pLoc is Map ? pLoc['updatedAt'] as String? : null,
      assignedAt: m['assignedAt'] as String?,
      pickedUpAt: m['pickedUpAt'] as String?,
      deliveredAt: m['deliveredAt'] as String?,
      deliveryInstructions: m['deliveryInstructions'] as String?,
      customerLat: coords is Map ? toDouble(coords['latitude']) : null,
      customerLng: coords is Map ? toDouble(coords['longitude']) : null,
      restaurantId:
          (m['restaurant'] is Map ? m['restaurant']['id'] : null) as String?,
      restaurantName:
          (m['restaurant'] is Map ? m['restaurant']['name'] : null) as String?,
      cutleryOptIn: m['cutleryOptIn'] as bool?,
      guaranteeEligible: guarantee is Map
          ? (guarantee['eligible'] as bool? ?? false)
          : false,
      guaranteeText: guarantee is Map ? guarantee['text'] as String? : null,
    );
  }
}

class OrderRepo {
  final ApiClient _client = ApiClient();

  static String get _cid =>
      'customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}';

  Future<List<dynamic>?> fetchOrders() async {
    try {
      final res = await _client.get('/orders?$_cid');
      if (res.statusCode != 200) {
        debugPrint('OrderRepo.fetchOrders: HTTP ${res.statusCode} ${res.body}');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded['orders'] is List ? decoded['orders'] as List : const [];
    } on TimeoutException catch (e) {
      debugPrint('OrderRepo.fetchOrders: timeout — $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('OrderRepo.fetchOrders: socket — $e');
      return null;
    } catch (e) {
      debugPrint('OrderRepo.fetchOrders: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchOrderById(String id) async {
    try {
      final res = await _client.get('/orders/${Uri.encodeComponent(id)}');
      if (res.statusCode != 200) {
        debugPrint('OrderRepo.fetchOrderById: HTTP ${res.statusCode}');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded['order'] is Map<String, dynamic>
          ? decoded['order'] as Map<String, dynamic>
          : null;
    } on TimeoutException catch (e) {
      debugPrint('OrderRepo.fetchOrderById: timeout — $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('OrderRepo.fetchOrderById: socket — $e');
      return null;
    } catch (e) {
      debugPrint('OrderRepo.fetchOrderById: $e');
      return null;
    }
  }

  /// Live tracking payload — partner, location, ETA, coordinates,
  /// instructions, guarantee. Returns null on network failure.
  Future<LiveTracking?> fetchLiveTracking(String id) async {
    try {
      final res = await _client.get(
        '/orders/${Uri.encodeComponent(id)}/live-tracking',
      );
      if (res.statusCode != 200) {
        debugPrint('OrderRepo.fetchLiveTracking: HTTP ${res.statusCode}');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      return LiveTracking.fromJson(decoded);
    } on TimeoutException catch (e) {
      debugPrint('OrderRepo.fetchLiveTracking: timeout — $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('OrderRepo.fetchLiveTracking: socket — $e');
      return null;
    } on FormatException catch (e) {
      debugPrint('OrderRepo.fetchLiveTracking: bad JSON — $e');
      return null;
    } catch (e) {
      debugPrint('OrderRepo.fetchLiveTracking: $e');
      return null;
    }
  }

  Future<List<dynamic>> trackingSteps(String id) async {
    try {
      final res = await _client.get(
        '/orders/${Uri.encodeComponent(id)}/tracking',
      );
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      return decoded['steps'] is List ? decoded['steps'] as List : const [];
    } catch (e) {
      return const [];
    }
  }

  /// Places the order server-side. Returns the stored order map or null.
  Future<Map<String, dynamic>?> placeOrder(Map<String, dynamic> body) async {
    try {
      final res = await _client.post(
        '/checkout/place',
        body: {...body, 'customerId': CustomerIdentity.customerId},
        timeout: const Duration(seconds: 60),
      );
      if (res.statusCode != 201) {
        debugPrint('OrderRepo.placeOrder: HTTP ${res.statusCode} ${res.body}');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded['order'] is Map<String, dynamic>
          ? decoded['order'] as Map<String, dynamic>
          : null;
    } on TimeoutException catch (e) {
      debugPrint('OrderRepo.placeOrder: timeout — $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('OrderRepo.placeOrder: socket — $e');
      return null;
    } on FormatException catch (e) {
      debugPrint('OrderRepo.placeOrder: bad JSON — $e');
      return null;
    } catch (e) {
      debugPrint('OrderRepo.placeOrder: $e');
      return null;
    }
  }

  Future<bool> saveDeliveryInstructions(String id, String instructions) async {
    try {
      final res = await _client.post(
        '/orders/${Uri.encodeComponent(id)}/delivery-instructions',
        body: {
          'instructions': instructions,
          'customerId': CustomerIdentity.customerId,
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('OrderRepo.saveDeliveryInstructions: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String id) async {
    try {
      final res = await _client.get(
        '/orders/${Uri.encodeComponent(id)}/messages',
      );
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final list = decoded['messages'];
      if (list is! List) return const [];
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('OrderRepo.fetchMessages: $e');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> sendMessage(String id, String body) async {
    try {
      final res = await _client.post(
        '/orders/${Uri.encodeComponent(id)}/messages',
        body: {
          'senderRole': 'customer',
          'body': body,
          'customerId': CustomerIdentity.customerId,
        },
      );
      if (res.statusCode != 201) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded['message'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(decoded['message'] as Map)
          : null;
    } catch (e) {
      debugPrint('OrderRepo.sendMessage: $e');
      return null;
    }
  }

  Future<bool> cancelOrder(String id) async {
    try {
      final res = await _client.post(
        '/orders/${Uri.encodeComponent(id)}/cancel',
        body: {'customerId': CustomerIdentity.customerId},
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
