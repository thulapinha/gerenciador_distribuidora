// lib/core/formats.dart
import 'package:intl/intl.dart';

final brDate = DateFormat('dd/MM/yyyy');
final brMoney = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');