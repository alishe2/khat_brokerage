import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NotificationCard(
            icon: Icons.info_outline,
            title: 'No new notifications',
            message:
                'Important business notifications will appear here.',
            time: 'Now',
          ),

          const SizedBox(height: 12),

          _NotificationCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Business activity',
            message:
                'Notifications about sales, farmer withdrawals, buyer payments and worker fees will appear here.',
            time: 'Today',
          ),

          const SizedBox(height: 12),

          _NotificationCard(
            icon: Icons.warning_amber_outlined,
            title: 'Debt reminders',
            message:
                'Unpaid buyer debts can be shown here when the notification system is connected.',
            time: 'Today',
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String time;

  const _NotificationCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(message),
        ),
        trailing: Text(
          time,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}