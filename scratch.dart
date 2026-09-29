import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  final url = dotenv.env['SUPABASE_URL']!;
  final key = dotenv.env['SUPABASE_ANON_KEY']!;
  
  final client = SupabaseClient(url, key);
  
  try {
    final res = await client.from('businesses').select().limit(1);
    if (res.isNotEmpty) {
      print('Columns in businesses table:');
      print(res.first.keys.toList());
    } else {
      print('No rows found, cannot infer schema this way.');
    }
  } catch (e) {
    print('Error: $e');
  }
}
