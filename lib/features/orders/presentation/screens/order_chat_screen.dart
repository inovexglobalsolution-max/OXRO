import 'dart:async';

import 'package:flutter/material.dart';

import 'package:oxro/app/api/customer_identity.dart';
import 'package:oxro/app/repositories/order_repo.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';

/// Realtime-ish order chat: polls the backend every 6 seconds while open
/// (cheap: single GET on orders/:id/messages). No message fabrication —
/// Partner responses come from the delivery partner's own app.
class OrderChatScreen extends StatefulWidget {
  const OrderChatScreen({super.key, required this.orderId, this.partnerName});

  final String orderId;
  final String? partnerName;

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final _repo = OrderRepo();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  Timer? _poll;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _refresh(silent: true),
    );
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!CustomerIdentity.networkEnabled && !silent) {
      // Widget tests run offline — render an empty thread, no network.
      if (mounted) setState(() => _loading = false);
      return;
    }
    final list = await _repo.fetchMessages(widget.orderId);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(list);
      _loading = false;
    });
    if (!silent) _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await _repo.sendMessage(widget.orderId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent == null) {
      showOxroSnack(context, 'Message not sent — try again');
      return;
    }
    _controller.clear();
    _messages.add(Map<String, dynamic>.from(sent));
    setState(() {});
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final partner = widget.partnerName ?? 'Delivery partner';
    return Scaffold(
      backgroundColor: OxroColors.pageBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(partner, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Text(
              'Order chat',
              style: TextStyle(fontSize: 11, color: OxroColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('chat_refresh'),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? _emptyState(partner)
                  : ListView.builder(
                      key: const ValueKey('chat_messages'),
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) => _messageBubble(_messages[i]),
                    ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String partner) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: context.rs(48),
            color: OxroColors.muted,
          ),
          const SizedBox(height: 10),
          Text(
            'Message $partner',
            key: const ValueKey('chat_empty'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: OxroColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Keep it about this order — delivery instructions,\naccess to your building, etc.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: OxroColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> m) {
    final mine = (m['senderRole'] as String?) == 'customer';
    final body = (m['body'] as String?) ?? '';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: ValueKey('chat_msg_${m['id'] ?? body.hashCode}'),
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? OxroColors.green : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: mine ? null : Border.all(color: OxroColors.border),
        ),
        child: Text(
          body,
          style: TextStyle(
            fontSize: 13.5,
            color: mine ? Colors.white : OxroColors.charcoal,
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(context.padX, 8, context.padX, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('chat_input'),
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    filled: true,
                    fillColor: OxroColors.pageBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('chat_send'),
                tooltip: 'Send',
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: OxroColors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
