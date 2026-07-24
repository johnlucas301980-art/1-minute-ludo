import 'package:flutter/material.dart';

import '../models/faq_item.dart';
import '../models/support_ticket.dart';
import '../services/support_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold    = Color(0xFFFFD700);
const _kBorder  = Color(0xFF2D2D4E);

/// Help & Support screen — Phase 9.3.
///
/// Shows three sections via a [DefaultTabController]:
/// - **FAQ**       — expandable list of frequently-asked questions.
/// - **Contact**   — form to submit a new support ticket.
/// - **My Tickets** — list of the player's previously submitted tickets.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.supportService});

  final SupportService supportService;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('support_screen'),
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: _kSurface,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _kGold,
          unselectedLabelColor: Colors.white54,
          indicatorColor: _kPrimary,
          tabs: const [
            Tab(key: Key('faq_tab'),     text: 'FAQ'),
            Tab(key: Key('contact_tab'), text: 'Contact'),
            Tab(key: Key('tickets_tab'), text: 'My Tickets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FaqTab(supportService: widget.supportService),
          _ContactTab(
            supportService: widget.supportService,
            onTicketSubmitted: () => _tabController.animateTo(2),
          ),
          _TicketsTab(supportService: widget.supportService),
        ],
      ),
    );
  }
}

// ─── FAQ tab ──────────────────────────────────────────────────────────────────

class _FaqTab extends StatefulWidget {
  const _FaqTab({required this.supportService});
  final SupportService supportService;

  @override
  State<_FaqTab> createState() => _FaqTabState();
}

class _FaqTabState extends State<_FaqTab>
    with AutomaticKeepAliveClientMixin {
  List<FaqItem>? _faqs;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final faqs = await widget.supportService.getFaqs();
      if (mounted) setState(() { _faqs = faqs; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load FAQs. Pull down to retry.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('faq_loading'),
          color: _kPrimary,
        ),
      );
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        color: _kPrimary,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  _error!,
                  key: const Key('faq_error'),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final faqs = _faqs ?? const [];
    if (faqs.isEmpty) {
      return const Center(
        child: Text(
          'No FAQs available.',
          key: Key('faq_empty'),
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Group FAQs by category.
    final categories = <String>[];
    final byCategory = <String, List<FaqItem>>{};
    for (final faq in faqs) {
      if (!byCategory.containsKey(faq.category)) {
        categories.add(faq.category);
        byCategory[faq.category] = [];
      }
      byCategory[faq.category]!.add(faq);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _kPrimary,
      child: ListView.builder(
        key: const Key('faq_list'),
        padding: const EdgeInsets.all(12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final items = byCategory[category]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: _kGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              ...items.map((faq) => _FaqTile(faq: faq)),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});
  final FaqItem faq;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _kSurface,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _kBorder),
      ),
      child: ExpansionTile(
        key: Key('faq_tile_${faq.id}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        iconColor: _kPrimary,
        collapsedIconColor: Colors.white54,
        title: Text(
          faq.question,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        children: [
          Text(
            faq.answer,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─── Contact tab ──────────────────────────────────────────────────────────────

class _ContactTab extends StatefulWidget {
  const _ContactTab({
    required this.supportService,
    required this.onTicketSubmitted,
  });
  final SupportService supportService;
  final VoidCallback onTicketSubmitted;

  @override
  State<_ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<_ContactTab>
    with AutomaticKeepAliveClientMixin {
  final _formKey     = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool    _submitting = false;
  String? _errorBanner;
  bool    _submitted  = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _submitting = true; _errorBanner = null; });

    try {
      await widget.supportService.submitTicket(
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
      );
      if (mounted) {
        _subjectCtrl.clear();
        _messageCtrl.clear();
        setState(() { _submitting = false; _submitted = true; });
        widget.onTicketSubmitted();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting  = false;
          _errorBanner = e.toString().replaceFirst(RegExp(r'^.*?: '), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_submitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Ticket submitted!',
                key: Key('submit_success'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We\'ll get back to you as soon as possible.\nYou can track your ticket in the My Tickets tab.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('submit_another_button'),
                onPressed: () => setState(() => _submitted = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit another'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Submit a Request',
              style: TextStyle(
                color: _kGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Describe your issue and our team will review it shortly.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Error banner
            if (_errorBanner != null) ...[
              Container(
                key: const Key('submit_error_banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Text(
                  _errorBanner!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Subject field
            TextFormField(
              key: const Key('subject_field'),
              controller: _subjectCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Subject'),
              textInputAction: TextInputAction.next,
              maxLength: 255,
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.length < 3) return 'Subject must be at least 3 characters.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Message field
            TextFormField(
              key: const Key('message_field'),
              controller: _messageCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Message'),
              maxLines: 6,
              maxLength: 5000,
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.length < 10) return 'Message must be at least 10 characters.';
                return null;
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              key: const Key('submit_ticket_button'),
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      key: Key('submit_spinner'),
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Request', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kPrimary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      filled: true,
      fillColor: _kSurface,
      counterStyle: const TextStyle(color: Colors.white38),
    );
  }
}

// ─── My Tickets tab ───────────────────────────────────────────────────────────

class _TicketsTab extends StatefulWidget {
  const _TicketsTab({required this.supportService});
  final SupportService supportService;

  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab>
    with AutomaticKeepAliveClientMixin {
  List<SupportTicket>? _tickets;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final tickets = await widget.supportService.getTickets();
      if (mounted) setState(() { _tickets = tickets; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load tickets. Pull down to retry.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('tickets_loading'),
          color: _kPrimary,
        ),
      );
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        color: _kPrimary,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  _error!,
                  key: const Key('tickets_error'),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tickets = _tickets ?? const [];
    if (tickets.isEmpty) {
      return const Center(
        child: Text(
          'You have no support tickets.',
          key: Key('tickets_empty'),
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _kPrimary,
      child: ListView.separated(
        key: const Key('tickets_list'),
        padding: const EdgeInsets.all(12),
        itemCount: tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _TicketTile(ticket: tickets[index]),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('ticket_tile_${ticket.id}'),
      color: _kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _kBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _StatusIcon(status: ticket.status),
        title: Text(
          ticket.subject,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          ticket.message.length > 80
              ? '${ticket.message.substring(0, 80)}…'
              : ticket.message,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: _StatusBadge(status: ticket.status),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'open'        => (Icons.inbox_outlined, Colors.blue),
      'in_progress' => (Icons.pending_outlined, Colors.amber),
      'resolved'    => (Icons.check_circle_outline, Colors.green),
      'closed'      => (Icons.cancel_outlined, Colors.grey),
      _             => (Icons.help_outline, Colors.white54),
    };
    return Icon(icon, color: color);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'open'        => ('Open', Colors.blue),
      'in_progress' => ('In Progress', Colors.amber),
      'resolved'    => ('Resolved', Colors.green),
      'closed'      => ('Closed', Colors.grey),
      _             => (status, Colors.white54),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
