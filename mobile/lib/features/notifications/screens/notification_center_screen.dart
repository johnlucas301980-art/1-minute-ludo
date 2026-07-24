import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../services/notification_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({
    super.key,
    required this.notificationService,
  });

  final NotificationService notificationService;

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    widget.notificationService.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF1A1A2E),
        actions: [
          StreamBuilder<int>(
            stream: widget.notificationService.onUnreadCountChanged,
            initialData: widget.notificationService.unreadCount,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return TextButton(
                onPressed: count == 0
                    ? null
                    : widget.notificationService.markAllRead,
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationItem>>(
        stream: widget.notificationService.onNotificationsChanged,
        initialData: widget.notificationService.notifications,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <NotificationItem>[];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'You have no notifications.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return _NotificationTile(
                item: item,
                onTap: item.isRead
                    ? null
                    : () => widget.notificationService.markRead(item.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final NotificationItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: item.isRead
          ? const Color(0xFF1A1A2E)
          : const Color(0xFF242344),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          item.isRead
              ? Icons.notifications_none
              : Icons.notifications_active,
          color: item.isRead ? Colors.white54 : const Color(0xFFFFD700),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          item.message,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: item.isRead
            ? null
            : const Icon(Icons.circle, size: 10, color: Color(0xFF6C63FF)),
      ),
    );
  }
}