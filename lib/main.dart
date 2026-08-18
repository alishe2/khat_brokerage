import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://educvyywfvzwkaucjkym.supabase.co',
    publishableKey: 'sb_publishable_ccfbWESxEtZcZ5kx_-UmuQ_K0vDdVtO',
  );

  runApp(const KhatBrokerageApp());
}