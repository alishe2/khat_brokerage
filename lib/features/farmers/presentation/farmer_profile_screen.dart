import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FarmerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> farmer;

  const FarmerProfileScreen({super.key, required this.farmer});

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  final _supabase = Supabase.instance.client;

  late Map<String, dynamic> _farmer;

  @override
  void initState() {
    super.initState();
    _farmer = Map<String, dynamic>.from(widget.farmer);
  }

  double get _balance {
    return double.tryParse(_farmer['current_balance'].toString()) ?? 0;
  }

  Future<void> _reloadFarmer() async {
    try {
      final data = await _supabase
          .from('farmers')
          .select(
            'id, farmer_code, full_name, phone, current_balance, is_active',
          )
          .eq('id', _farmer['id'])
          .single();

      if (!mounted) return;

      setState(() {
        _farmer = Map<String, dynamic>.from(data);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not reload farmer: $e')));
    }
  }

  Future<void> _editFarmer() async {
    final nameController = TextEditingController(
      text: _farmer['full_name'] ?? '',
    );

    final phoneController = TextEditingController(text: _farmer['phone'] ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Farmer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter the farmer name')),
                  );
                  return;
                }

                try {
                  await _supabase
                      .from('farmers')
                      .update({
                        'full_name': name,
                        'phone': phone.isEmpty ? null : phone,
                        'updated_at': DateTime.now().toIso8601String(),
                      })
                      .eq('id', _farmer['id']);

                  if (!dialogContext.mounted) return;

                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Could not update farmer: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      phoneController.dispose();
    });

    if (saved == true) {
      await _reloadFarmer();
    }
  }

  Future<void> _deleteFarmer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Farmer'),
          content: const Text(
            'This farmer will be removed from the active farmer list. '
            'Existing sales and withdrawal history will remain.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('farmers')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _farmer['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farmer deleted successfully')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete farmer: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Profile'),
        actions: [
          IconButton(
            onPressed: _editFarmer,
            tooltip: 'Edit Farmer',
            icon: const Icon(Icons.edit_outlined),
          ),

          IconButton(
            onPressed: _deleteFarmer,
            tooltip: 'Delete Farmer',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _reloadFarmer,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const CircleAvatar(
              radius: 45,
              child: Icon(Icons.agriculture_outlined, size: 45),
            ),

            const SizedBox(height: 16),

            Text(
              _farmer['full_name'] ?? 'Unknown',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Current Balance',
                      style: TextStyle(fontSize: 14),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '${_balance.toStringAsFixed(2)} Birr',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Farmer ID'),
                    subtitle: Text(_farmer['farmer_code'] ?? 'No ID'),
                  ),

                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Full Name'),
                    subtitle: Text(_farmer['full_name'] ?? 'Unknown'),
                  ),

                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Phone'),
                    subtitle: Text(_farmer['phone'] ?? 'No phone number'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
