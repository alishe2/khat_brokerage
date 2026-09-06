import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _supabase = Supabase.instance.client;

  bool _isSigningOut = false;
  bool _isUpdatingProfile = false;
  bool _isChangingPassword = false;


  String _fullName = 'Administrator';
  String _phone = 'Not available';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ================================================================
  // LOAD ADMIN PROFILE
  // ================================================================

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) return;

      final data = await _supabase
          .from('users')
          .select('full_name, phone')
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      setState(() {
        _fullName = data['full_name']?.toString() ?? 'Administrator';
        _phone = data['phone']?.toString() ?? 'Not available';
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load profile: $e'),
        ),
      );
    }
  }

  // ================================================================
  // EDIT PROFILE
  // ================================================================

  Future<void> _editProfile() async {
    final nameController = TextEditingController(
      text: _fullName,
    );

    final phoneController = TextEditingController(
      text: _phone == 'Not available' ? '' : _phone,
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profile'),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(
                    Icons.person_outline,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                  ),
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter your full name.',
                      ),
                    ),
                  );
                  return;
                }

                if (phone.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter your phone number.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(
                  {
                    'full_name': name,
                    'phone': phone,
                  },
                );
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

    if (result == null) return;

    await _updateProfile(
      fullName: result['full_name']!,
      phone: result['phone']!,
    );
  }

  // ================================================================
  // UPDATE PROFILE IN DATABASE
  // ================================================================

  Future<void> _updateProfile({
    required String fullName,
    required String phone,
  }) async {
    setState(() {
      _isUpdatingProfile = true;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'You are not logged in.',
        );
      }

      await _supabase
          .from('users')
          .update({
            'full_name': fullName,
            'phone': phone,
          })
          .eq('id', user.id);

      if (!mounted) return;

      setState(() {
        _fullName = fullName;
        _phone = phone;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update profile: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingProfile = false;
        });
      }
    }
  }

  // ================================================================
  // CHANGE PASSWORD
  // ================================================================

  Future<void> _changePassword() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    final newPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Change Password',
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            obscureNewPassword =
                                !obscureNewPassword;
                          });
                        },
                        icon: Icon(
                          obscureNewPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            obscureConfirmPassword =
                                !obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child: const Text(
                    'Cancel',
                  ),
                ),

                FilledButton(
                  onPressed: () {
                    final password =
                        newPasswordController.text;

                    final confirmation =
                        confirmPasswordController.text;

                    if (password.isEmpty) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a new password.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (password.length < 6) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password must be at least 6 characters.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (password != confirmation) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Passwords do not match.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.of(
                      dialogContext,
                    ).pop(password);
                  },
                  child: const Text(
                    'Change Password',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });

    if (newPassword == null) return;

    setState(() {
      _isChangingPassword = true;
    });

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password changed successfully.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not change password: ${e.message}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not change password: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  // ================================================================
  // SIGN OUT
  // ================================================================

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Sign Out',
          ),

          content: const Text(
            'Are you sure you want to sign out?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Sign Out',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isSigningOut = true;
    });

    try {
      await _supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(
        context,
      ).popUntil(
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Could not sign out: $e',
          ),
        ),
      );

      setState(() {
        _isSigningOut = false;
      });
    }
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Account',
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),

        children: [
          // ==========================================================
          // PROFILE HEADER
          // ==========================================================

          const CircleAvatar(
            radius: 50,
            child: Icon(
              Icons.admin_panel_settings_outlined,
              size: 50,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            _fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Business Owner',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 20),

          // ==========================================================
          // EDIT PROFILE BUTTON
          // ==========================================================

          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isUpdatingProfile
                  ? null
                  : _editProfile,
              icon: const Icon(
                Icons.edit_outlined,
              ),
              label: const Text(
                'Edit Profile',
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ==========================================================
          // PERSONAL INFORMATION
          // ==========================================================

          const Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                  ),
                  title: const Text(
                    'Full Name',
                  ),
                  subtitle: Text(
                    _fullName,
                  ),
                ),

                const Divider(
                  height: 1,
                ),

                ListTile(
                  leading: const Icon(
                    Icons.phone_outlined,
                  ),
                  title: const Text(
                    'Phone',
                  ),
                  subtitle: Text(
                    _phone,
                  ),
                ),

                const Divider(
                  height: 1,
                ),

                const ListTile(
                  leading: Icon(
                    Icons.security_outlined,
                  ),
                  title: Text(
                    'Role',
                  ),
                  subtitle: Text(
                    'Administrator',
                  ),
                  trailing: Icon(
                    Icons.lock_outline,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ==========================================================
          // ACCOUNT ACTIONS
          // ==========================================================

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.lock_outline,
                  ),
                  title: const Text(
                    'Change Password',
                  ),
                  trailing: _isChangingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.chevron_right,
                        ),
                  onTap: _isChangingPassword
                      ? null
                      : _changePassword,
                ),

                const Divider(
                  height: 1,
                ),

                ListTile(
                  leading: const Icon(
                    Icons.logout,
                  ),
                  title: const Text(
                    'Sign Out',
                  ),
                  trailing: _isSigningOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.chevron_right,
                        ),
                  onTap: _isSigningOut
                      ? null
                      : _signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}