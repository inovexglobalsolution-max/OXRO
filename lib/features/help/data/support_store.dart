import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/app/api/customer_identity.dart';
import 'package:oxro/app/repositories/support_repo.dart';

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
  bool _serverEmpty = false;

  @visibleForTesting
  static void resetForTests() {
    instance._tickets.clear();
    instance.notifyListeners();
  }

  Future<void> _maybeSeedServer() async {
    if (!_serverEmpty || !CustomerIdentity.networkEnabled || _tickets.isEmpty) {
      _serverEmpty = false;
      return;
    }
    try {
      for (final t in _tickets) {
        await SupportRepo().create({
          'id': t.id,
          'source': t.source.name,
          'categoryId': t.categoryId,
          'categoryLabel': t.categoryLabel,
          'orderId': t.orderId,
          'restaurantName': t.restaurantName,
          'items': t.items,
          'note': t.note,
        });
      }
    } catch (_) {
      // Local cache remains authoritative; the next sync can retry.
    } finally {
      _serverEmpty = false;
    }
  }

  Future<void> load() async {
    _serverEmpty = false;
    if (CustomerIdentity.networkEnabled) {
      try {
        final remote = await SupportRepo().list();
        if (remote != null && remote.isNotEmpty) {
          final loaded = <SupportTicket>[];
          for (final e in remote) {
            if (e is Map<String, dynamic>) {
              final t = SupportTicket.fromJson(e);
              if (t.id.isNotEmpty) loaded.add(t);
            }
          }
          if (loaded.isNotEmpty) {
            _tickets
              ..clear()
              ..addAll(loaded);
            notifyListeners();
            await _persist();
            return;
          }
        }
        if (remote != null) _serverEmpty = true;
      } catch (_) {
        // Offline — the local cache stays authoritative.
      }
    }
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null || raw.isEmpty) {
        await _maybeSeedServer();
        return;
      }
      final list = jsonDecode(raw) as List;
      final loaded = <SupportTicket>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final t = SupportTicket.fromJson(e);
          if (t.id.isNotEmpty) loaded.add(t);
        }
      }
      if (loaded.isEmpty) {
        await _maybeSeedServer();
        return;
      }
      _tickets
        ..clear()
        ..addAll(loaded);
      notifyListeners();
    } catch (_) {
      await _maybeSeedServer();
      return;
    }
    await _maybeSeedServer();
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
    if (CustomerIdentity.networkEnabled) {
      unawaited(() async {
        try {
          await SupportRepo().create({
            'id': ticket.id,
            'source': ticket.source.name,
            'categoryId': ticket.categoryId,
            'categoryLabel': ticket.categoryLabel,
            'orderId': ticket.orderId,
            'restaurantName': ticket.restaurantName,
            'items': ticket.items,
            'note': ticket.note,
          });
        } catch (_) {
          // Best-effort sync only.
        }
      }());
    }
    return ticket;
  }

  List<SupportTicket> get recent => List.unmodifiable(_tickets);

  List<SupportTicket> forOrder(String orderId) =>
      List.unmodifiable(_tickets.where((t) => t.orderId == orderId));
}
