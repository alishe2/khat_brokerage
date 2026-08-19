import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:khat_brokerage/features/farmers/presentation/add_farmer_screen.dart';
import 'package:khat_brokerage/features/farmers/presentation/farmer_profile_screen.dart';

class FarmersScreen extends StatefulWidget {
  const FarmersScreen({super.key});

  @override
  State<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends State<FarmersScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _farmers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarmers();
  }

  Future<void> _loadFarmers() async {
    try {
      final data = await _supabase
          .from('farmers')
          .select(
            'id, farmer_code, full_name, phone, current_balance, is_active',
          )
          .eq('is_active', true)
          .order('full_name');

      if (!mounted) return;

      setState(() {
        _farmers = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load farmers: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farmers')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddFarmerScreen()),
          );

          if (result == true && mounted) {
            await _loadFarmers();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Farmer'),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFarmers,

              child: _farmers.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 150),
                        Center(child: Text('No farmers registered yet.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _farmers.length,

                      itemBuilder: (context, index) {
                        final farmer = _farmers[index];

                        final balance = farmer['current_balance'] ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),

                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),

                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FarmerProfileScreen(farmer: farmer),
                                ),
                              );

                              // Refresh the list after returning from the profile.
                              if (mounted) {
                                await _loadFarmers();
                              }
                            },

                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),

                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 26,
                                    child: Icon(Icons.agriculture_outlined),
                                  ),

                                  const SizedBox(width: 14),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Text(
                                          farmer['full_name'] ?? 'Unknown',

                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),

                                        const SizedBox(height: 4),

                                        Text(
                                          farmer['farmer_code'] ?? 'No ID',

                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),

                                        const SizedBox(height: 2),

                                        Text(
                                          farmer['phone'] ?? 'No phone number',

                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,

                                    children: [
                                      Text(
                                        'Balance',

                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),

                                      const SizedBox(height: 3),

                                      Text(
                                        '$balance Birr',

                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      const Icon(Icons.chevron_right, size: 20),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
