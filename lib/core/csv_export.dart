// lib/core/csv_export.dart
import 'dart:io';
import 'package:csv/csv.dart';

Future<File> saveCsv(String filename, List<List<dynamic>> rows, Directory dir) async {
  final csv = const ListToCsvConverter().convert(rows);
  final file = File('${dir.path}/$filename');
  return file.writeAsString(csv);
}