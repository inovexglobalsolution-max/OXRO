import 'package:flutter/material.dart';

/// Shared premium snackbar — floating, rounded, margined.
/// Replaces every raw SnackBar so notices feel consistent app-wide.
void showOxroSnack(BuildContext context, String msg) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
