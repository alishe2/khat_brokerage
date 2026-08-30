import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountantScreen extends StatefulWidget {
  const AccountantScreen({super.key});

  @override
  State<AccountantScreen> createState() => _AccountantScreenState();
}

class _AccountantScreenState extends State<AccountantScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  bool _accountantEnabled = true;

  bool _canManageFarmers = false;
  bool _canManageBuyers = false;
  bool _canRecordSales = false;
  bool _canRecordFarmerWithdrawals = false;
  bool _canRecordBuyerPayments = false;
  bool _canManageSellers = false;
  bool _canViewReports = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  // ================================================================
  // LOAD ACCOUNTANT PERMISSIONS
  // ================================================================

  Future<void> _loadPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _supabase
          .from('accountant_permissions')
          .select()
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        setState(() {
          _canManageFarmers = data['can_manage_farmers'] == true;

          _canManageBuyers = data['can_manage_buyers'] == true;

          _canRecordSales = data['can_record_sales'] == true;

          _canRecordFarmerWithdrawals =
              data['can_record_farmer_withdrawals'] == true;

          _canRecordBuyerPayments = data['can_record_buyer_payments'] == true;

          _canManageSellers = data['can_manage_sellers'] == true;

          _canViewReports = data['can_view_reports'] == true;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load accountant permissions: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ================================================================
  // SAVE PERMISSIONS
  // ================================================================

  Future<void> _savePermissions() async {
    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must be logged in as Admin to change permissions.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final permissionRow = await _supabase
          .from('accountant_permissions')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (permissionRow == null) {
        throw Exception('Accountant permission record was not found.');
      }

      final permissionId = permissionRow['id'];

      await _supabase
          .from('accountant_permissions')
          .update({
            'can_manage_farmers': _canManageFarmers,
            'can_manage_buyers': _canManageBuyers,
            'can_record_sales': _canRecordSales,
            'can_record_farmer_withdrawals': _canRecordFarmerWithdrawals,
            'can_record_buyer_payments': _canRecordBuyerPayments,
            'can_manage_sellers': _canManageSellers,
            'can_view_reports': _canViewReports,
            'updated_by': currentUser.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', permissionId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accountant permissions saved successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save permissions: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accountant')),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPermissions,

              child: ListView(
                padding: const EdgeInsets.all(16),

                children: [
                  // ==================================================
                  // ACCOUNTANT PROFILE
                  // ==================================================
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),

                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 32,

                            child: Icon(Icons.calculate_outlined, size: 32),
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
                                  _accountantEnabled
                                      ? 'Accountant access enabled'
                                      : 'Accountant access restricted',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // ACCOUNTANT ACCESS
                  // ==================================================
                  const Text(
                    'Accountant Access',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        style: TextStyle(fontWeight: FontWeight.w600),
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

                  // ==================================================
                  // PERMISSIONS
                  // ==================================================
                  const Text(
                    'Permissions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  _PermissionTile(
                    icon: Icons.agriculture_outlined,
                    title: 'Farmers',
                    subtitle: 'Register and manage farmer information',
                    value: _canManageFarmers,
                    onChanged: (value) {
                      setState(() {
                        _canManageFarmers = value;
                      });
                    },
                  ),

                  _PermissionTile(
                    icon: Icons.groups_outlined,
                    title: 'Buyers',
                    subtitle: 'Register and manage buyer information',
                    value: _canManageBuyers,
                    onChanged: (value) {
                      setState(() {
                        _canManageBuyers = value;
                      });
                    },
                  ),

                  _PermissionTile(
                    icon: Icons.person_outline,
                    title: 'Sellers',
                    subtitle: 'Register and manage sellers',
                    value: _canManageSellers,
                    onChanged: (value) {
                      setState(() {
                        _canManageSellers = value;
                      });
                    },
                  ),

                  _PermissionTile(
                    icon: Icons.point_of_sale_outlined,
                    title: 'Record Sales',
                    subtitle: 'Record and finalize sales transactions',
                    value: _canRecordSales,
                    onChanged: (value) {
                      setState(() {
                        _canRecordSales = value;
                      });
                    },
                  ),

                  _PermissionTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Farmer Withdrawals',
                    subtitle: 'Record farmer withdrawals',
                    value: _canRecordFarmerWithdrawals,
                    onChanged: (value) {
                      setState(() {
                        _canRecordFarmerWithdrawals = value;
                      });
                    },
                  ),

                  _PermissionTile(
                    icon: Icons.payments_outlined,
                    title: 'Buyer Payments',
                    subtitle: 'Record payments made by buyers',
                    value: _canRecordBuyerPayments,
                    onChanged: (value) {
                      setState(() {
                        _canRecordBuyerPayments = value;
                      });
                    },
                  ),

                  _PermissionTile(
                    icon: Icons.bar_chart_outlined,
                    title: 'Reports',
                    subtitle: 'View business reports',
                    value: _canViewReports,
                    onChanged: (value) {
                      setState(() {
                        _canViewReports = value;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // SAVE BUTTON
                  // ==================================================
                  SizedBox(
                    height: 52,

                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _savePermissions,

                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),

                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Permissions',

                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // INFORMATION
                  // ==================================================
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),

                      title: const Text(
                        'How this works',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),

                      subtitle: const Text(
                        'These permissions control what the accountant '
                        'will be allowed to access after logging in.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ==================================================================
// PERMISSION TILE
// ==================================================================

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),

      child: SwitchListTile(
        value: value,

        onChanged: onChanged,

        secondary: CircleAvatar(child: Icon(icon)),

        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),

        subtitle: Text(subtitle),
      ),
    );
  }
}
