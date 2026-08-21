import 'package:flutter/material.dart';

class AccountantScreen extends StatefulWidget {
  const AccountantScreen({super.key});

  @override
  State<AccountantScreen> createState() => _AccountantScreenState();
}

class _AccountantScreenState extends State<AccountantScreen> {
  bool _accountantEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accountant'),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Accountant profile header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    child: Icon(
                      Icons.calculate_outlined,
                      size: 32,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Accountant',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Business accountant',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Accountant Access',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Card(
            child: SwitchListTile(
              value: _accountantEnabled,
              onChanged: (value) {
                setState(() {
                  _accountantEnabled = value;
                });
              },
              title: const Text(
                'Accountant access',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _accountantEnabled
                    ? 'Accountant can access the system'
                    : 'Accountant access is restricted',
              ),
              secondary: Icon(
                _accountantEnabled
                    ? Icons.lock_open_outlined
                    : Icons.lock_outline,
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Permissions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          _PermissionTile(
            icon: Icons.agriculture_outlined,
            title: 'Farmers',
            subtitle: 'Register and manage farmer information',
          ),

          _PermissionTile(
            icon: Icons.groups_outlined,
            title: 'Buyers',
            subtitle: 'Register and manage buyer information',
          ),

          _PermissionTile(
            icon: Icons.person_outline,
            title: 'Sellers',
            subtitle: 'Register and manage sellers',
          ),

          _PermissionTile(
            icon: Icons.receipt_long_outlined,
            title: 'Record Sales',
            subtitle: 'Record and finalize sales transactions',
          ),

          _PermissionTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Farmer Withdrawals',
            subtitle: 'Record farmer withdrawals',
          ),

          _PermissionTile(
            icon: Icons.payments_outlined,
            title: 'Buyer Payments',
            subtitle: 'Record payments made by buyers',
          ),

          const SizedBox(height: 24),

          Card(
            child: ListTile(
              leading: const Icon(
                Icons.info_outline,
              ),
              title: const Text(
                'Accountant restrictions',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Permission controls will be connected to the database next.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.check_circle_outline,
        ),
      ),
    );
  }
}