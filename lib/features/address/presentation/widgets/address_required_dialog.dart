import 'package:flutter/material.dart';

import 'package:oxro/features/address/data/address_store.dart';

/// Blocks checkout with a specific, actionable address message.
/// Returns true when the user chooses to add / complete the address.
Future<bool> showAddressRequiredDialog(
  BuildContext context,
  AddressIssue issue,
) async {
  final (key, title, message, action) = switch (issue) {
    AddressIssue.missing => (
      const ValueKey('address_gate_missing'),
      'Add your address first',
      'No delivery address yet. Add your flat / door number so we know '
          'where to send this order.',
      'Add address',
    ),
    AddressIssue.doorMissing => (
      const ValueKey('address_gate_door'),
      'Door number missing',
      'Your location is set, but the flat / door number is missing. '
          'Complete your address before placing the order.',
      'Complete address',
    ),
    _ => (
      const ValueKey('address_gate_incomplete'),
      'Complete your address',
      'A few address details are missing. Finish them before placing '
          'the order.',
      'Complete address',
    ),
  };

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: key,
      title: Text(title, key: const ValueKey('address_gate_title')),
      content: Text(message, key: const ValueKey('address_gate_message')),
      actions: [
        TextButton(
          key: const ValueKey('address_gate_later'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          key: const ValueKey('address_gate_primary'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return go ?? false;
}
