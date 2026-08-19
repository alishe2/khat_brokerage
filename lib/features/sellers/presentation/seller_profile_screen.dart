import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> seller;

  const SellerProfileScreen({super.key, required this.seller});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final _supabase = Supabase.instance.client;

  late Map<String, dynamic> _seller;

  @override
  void initState() {
    super.initState();
    _seller = Map<String, dynamic>.from(widget.seller);
  }

  Future<void> _editSeller() async {
    final nameController = TextEditingController(text: _seller['full_name']);
    final phoneController = TextEditingController(text: _seller['phone'] ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Seller'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  return;
                }

                try {
                  await _supabase
                      .from('sellers')
                      .update({
                        'full_name': nameController.text.trim(),
                        'phone': phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                        'updated_at': DateTime.now().toIso8601String(),
                      })
                      .eq('id', _seller['id']);

                  if (!dialogContext.mounted) return;

                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Could not update seller: $e')),
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
      await _reloadSeller();
    }
  }

  Future<void> _reloadSeller() async {
    final data = await _supabase
        .from('sellers')
        .select('id, seller_code, full_name, phone, is_active')
        .eq('id', _seller['id'])
        .single();

    if (!mounted) return;

    setState(() {
      _seller = Map<String, dynamic>.from(data);
    });
  }

  Future<void> _deleteSeller() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Seller'),
          content: const Text(
            'The seller will be removed from the active seller list. '
            'Existing sales history will remain.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('sellers')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _seller['id']);

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete seller: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Profile'),
        actions: [
          IconButton(
            onPressed: _editSeller,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _deleteSeller,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 45,
            child: Icon(Icons.person_outline, size: 45),
          ),

          const SizedBox(height: 16),

          Text(
            _seller['full_name'] ?? 'Unknown',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 24),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Seller Code'),
                  subtitle: Text(_seller['seller_code'] ?? 'No code'),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Full Name'),
                  subtitle: Text(_seller['full_name'] ?? 'Unknown'),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Phone'),
                  subtitle: Text(_seller['phone'] ?? 'No phone number'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
