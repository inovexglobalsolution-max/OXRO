import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SupportSource { order, bag }

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.source,
    required this.categoryId,
    required this.categoryLabel,
    required this.createdAt,
    this.orderId,
    this.restaurantName,
    this.items = const [],
    this.note = '',
    this.status = 'Submitted',
  });

  final String id;
  final SupportSource source;
  final String categoryId;
  final String categoryLabel;
  final DateTime createdAt;
  final String? orderId;
  final String? restaurantName;
  final List<String> items;
  final String note;
  final String status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source.name,
    'categoryId': categoryId,
    'categoryLabel': categoryLabel,
    'createdAt': createdAt.toIso8601String(),
    'orderId': orderId,
    'restaurantName': restaurantName,
    'items': items,
    'note': note,
    'status': status,
  };

  factory SupportTicket.fromJson(Map<String, dynamic> m) {
    final sourceName = m['source'] as String?;
    final source = SupportSource.values.firstWhere(
      (s) => s.name == sourceName,
      orElse: () => SupportSource.order,
    );
    return SupportTicket(
      id: (m['id'] as String?) ?? '',
      source: source,
      categoryId: (m['categoryId'] as String?) ?? 'other',
      categoryLabel: (m['categoryLabel'] as String?) ?? 'Other',
      createdAt:
          DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      orderId: m['orderId'] as String?,
      restaurantName: m['restaurantName'] as String?,
      items: [
        for (final v in (m['items'] is List ? m['items'] as List : const []))
          if (v is String) v,
      ],
      note: (m['note'] as String?) ?? '',
      status: (m['status'] as String?) ?? 'Submitted',
    );
  }
}

class SupportStore extends ChangeNotifier {
  SupportStore._();

  static final SupportStore instance = SupportStore._();

  static const _kCache = 'oxro_support_v1';

  final List<SupportTicket> _tickets = [];

  @visibleForTesting
  static void resetForTests() {
    instance._tickets.clear();
    instance.notifyListeners();
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      final loaded = <SupportTicket>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final t = SupportTicket.fromJson(e);
          if (t.id.isNotEmpty) loaded.add(t);
        }
      }
      if (loaded.isEmpty) return;
      _tickets
        ..clear()
        ..addAll(loaded);
      notifyListeners();
    } catch (_) {
      return;
    }
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _kCache,
        jsonEncode([for (final t in _tickets) t.toJson()]),
      );
    } catch (_) {
      return;
    }
  }

  SupportTicket submit({
    required SupportSource source,
    required String categoryId,
    required String categoryLabel,
    String? orderId,
    String? restaurantName,
    List<String> items = const [],
    String note = '',
  }) {
    final ticket = SupportTicket(
      id: 'OXR-${DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      source: source,
      categoryId: categoryId,
      categoryLabel: categoryLabel,
      createdAt: DateTime.now(),
      orderId: orderId,
      restaurantName: restaurantName,
      items: List.unmodifiable(items),
      note: note.trim(),
    );
    _tickets.insert(0, ticket);
    notifyListeners();
    _persist();
    return ticket;
  }

  List<SupportTicket> get recent => List.unmodifiable(_tickets);

  List<SupportTicket> forOrder(String orderId) =>
      List.unmodifiable(_tickets.where((t) => t.orderId == orderId));
}
