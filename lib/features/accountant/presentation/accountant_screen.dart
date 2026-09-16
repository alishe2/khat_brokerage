import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountantScreen extends StatefulWidget {
  const AccountantScreen({super.key});

  @override
  State<AccountantScreen> createState() => _AccountantScreenState();
}

class _AccountantScreenState extends State<AccountantScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  String _accountantName = 'Accountant';
  String _accountantPhone = '';

  // Master toggle
  bool _accountantEnabled = true;

  // Accountant visibility permissions
  bool _showDashboard = true;
  bool _showRecordSale = true;
  bool _showFarmers = true;
  bool _showBuyers = true;
  bool _showSellers = true;
  bool _showTransactions = true;
  bool _showReports = true;
  bool _showExpenses = true;
  bool _allowSaleEdit = false;

  @override
  void initState() {
    super.initState();
    _loadAccountantData();
  }

  Future<void> _loadAccountantData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final accountant = await _supabase
          .from('users')
          .select('id, full_name, phone')
          .eq('role', 'accountant')
          .maybeSingle();

      if (accountant != null) {
        _accountantName =
            (accountant['full_name'] as String?)?.trim().isNotEmpty == true
            ? accountant['full_name'] as String
            : 'Accountant';

        _accountantPhone = accountant['phone'] as String? ?? '';
      }

      final permissions = await _supabase
          .from('accountant_permissions')
          .select('''
            id,
            accountant_enabled,
            show_dashboard_to_accountant,
            show_record_sale_to_accountant,
            show_farmers_to_accountant,
            show_buyers_to_accountant,
            show_sellers_to_accountant,
            show_transactions_to_accountant,
            show_reports_to_accountant,
            show_expenses_to_accountant,
            allow_sale_edit_to_accountant
          ''')
          .limit(1)
          .maybeSingle();

      if (permissions != null) {
        _accountantEnabled = permissions['accountant_enabled'] as bool? ?? true;

        _showDashboard =
            permissions['show_dashboard_to_accountant'] as bool? ?? true;

        _showRecordSale =
            permissions['show_record_sale_to_accountant'] as bool? ?? true;

        _showFarmers =
            permissions['show_farmers_to_accountant'] as bool? ?? true;

        _showBuyers = permissions['show_buyers_to_accountant'] as bool? ?? true;

        _showSellers =
            permissions['show_sellers_to_accountant'] as bool? ?? true;

        _showTransactions =
            permissions['show_transactions_to_accountant'] as bool? ?? true;

        _showReports =
            permissions['show_reports_to_accountant'] as bool? ?? true;

        _showExpenses =
            permissions['show_expenses_to_accountant'] as bool? ?? true;

        _allowSaleEdit =
            permissions['allow_sale_edit_to_accountant'] as bool? ?? false;
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to load accountant settings: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePermissions() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final existing = await _supabase
          .from('accountant_permissions')
          .select('id')
          .limit(1)
          .maybeSingle();

      final data = {
        'accountant_enabled': _accountantEnabled,
        'show_dashboard_to_accountant': _showDashboard,
        'show_record_sale_to_accountant': _showRecordSale,
        'show_farmers_to_accountant': _showFarmers,
        'show_buyers_to_accountant': _showBuyers,
        'show_sellers_to_accountant': _showSellers,
        'show_transactions_to_accountant': _showTransactions,
        'show_reports_to_accountant': _showReports,
        'show_expenses_to_accountant': _showExpenses,
        'allow_sale_edit_to_accountant': _allowSaleEdit,
        'updated_by': _supabase.auth.currentUser?.id,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing != null) {
        await _supabase
            .from('accountant_permissions')
            .update(data)
            .eq('id', existing['id']);
      } else {
        await _supabase.from('accountant_permissions').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accountant permissions saved successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save permissions: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final enabled = _accountantEnabled;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: SwitchListTile(
          value: value,
          onChanged: enabled ? onChanged : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          secondary: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.teal, size: 21),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          activeThumbColor: Colors.teal,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppBar(
        title: const Text(
          'Accountant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              color: Colors.teal,
              onRefresh: _loadAccountantData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -------------------------------------------------------
                    // ACCOUNTANT PROFILE
                    // -------------------------------------------------------
                    _buildSectionTitle('Accountant Profile'),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.teal,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _accountantName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_accountantPhone.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    _accountantPhone,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // -------------------------------------------------------
                    // ACCOUNTANT ACCESS - MASTER TOGGLE
                    // -------------------------------------------------------
                    _buildSectionTitle('Accountant Access'),

                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SwitchListTile(
                        value: _accountantEnabled,
                        onChanged: (value) {
                          setState(() {
                            _accountantEnabled = value;
                          });
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        secondary: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _accountantEnabled
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.red.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _accountantEnabled
                                ? Icons.lock_open_rounded
                                : Icons.lock_rounded,
                            color: _accountantEnabled
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        title: const Text(
                          'Accountant Access',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          _accountantEnabled
                              ? 'Accountant access is enabled'
                              : 'Accountant access is disabled',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        activeThumbColor: Colors.green,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // -------------------------------------------------------
                    // VISIBILITY PERMISSIONS
                    // -------------------------------------------------------
                    _buildSectionTitle('Dashboard & Quick Actions'),

                    _buildPermissionTile(
                      title: 'Dashboard',
                      subtitle: 'Allow accountant to see the dashboard',
                      icon: Icons.dashboard_rounded,
                      value: _showDashboard,
                      onChanged: (value) {
                        setState(() {
                          _showDashboard = value;
                        });
                      },
                    ),

                    _buildPermissionTile(
                      title: 'Record Sale',
                      subtitle: 'Allow accountant to access Record Sale',
                      icon: Icons.point_of_sale_rounded,
                      value: _showRecordSale,
                      onChanged: (value) {
                        setState(() {
                          _showRecordSale = value;
                        });
                      },
                    ),

                    _buildPermissionTile(
                      title: 'Farmers',
                      subtitle: 'Allow accountant to access Farmers',
                      icon: Icons.agriculture_rounded,
                      value: _showFarmers,
                      onChanged: (value) {
                        setState(() {
                          _showFarmers = value;
                        });
                      },
                    ),

                    _buildPermissionTile(
                      title: 'Buyers',
                      subtitle: 'Allow accountant to access Buyers',
                      icon: Icons.groups_rounded,
                      value: _showBuyers,
                      onChanged: (value) {
                        setState(() {
                          _showBuyers = value;
                        });
                      },
                    ),

                    _buildPermissionTile(
                      title: 'Sellers',
                      subtitle: 'Allow accountant to access Sellers',
                      icon: Icons.storefront_rounded,
                      value: _showSellers,
                      onChanged: (value) {
                        setState(() {
                          _showSellers = value;
                        });
                      },
                    ),

                    _buildPermissionTile(
                      title: 'Transactions',
                      subtitle: 'Allow accountant to access Transactions',
                      icon: Icons.receipt_long_rounded,
                      value: _showTransactions,
                      onChanged: (value) {
                        setState(() {
                          _showTransactions = value;
                        });
                      },
                    ),

                    _buildPermissionTile(
                      title: 'Reports',
                      subtitle: 'Allow accountant to access Reports',
                      icon: Icons.bar_chart_rounded,
                      value: _showReports,
                      onChanged: (value) {
                        setState(() {
                          _showReports = value;
                        });
                      },
                    ),

                    _buildPermissionTile(
                      title: 'Expenses',
                      subtitle: 'Allow accountant to access Expenses',
                      icon: Icons.account_balance_wallet_rounded,
                      value: _showExpenses,
                      onChanged: (value) {
                        setState(() {
                          _showExpenses = value;
                        });
                      },
                    ),

                    _buildPermissionTile(
                      title: 'Edit Sales',
                      subtitle:
                          'Allow accountant to correct saved sale records',
                      icon: Icons.edit_note_outlined,
                      value: _allowSaleEdit,
                      onChanged: (value) {
                        setState(() {
                          _allowSaleEdit = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // -------------------------------------------------------
                    // SAVE BUTTON
                    // -------------------------------------------------------
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _savePermissions,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Permissions',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.teal.withValues(
                            alpha: 0.55,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // -------------------------------------------------------
                    // INFORMATION CARD
                    // -------------------------------------------------------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.teal.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.teal,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Accountant Access is the master switch. '
                              'When it is turned off, the eight individual '
                              'visibility settings are disabled but their '
                              'saved values are preserved. When access is '
                              'enabled again, the previous settings return.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12.5,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
