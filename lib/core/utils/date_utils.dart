import 'package:intl/intl.dart';

class AppDate {
  AppDate._();

  static String relativeBangla(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays >= 7) {
      return DateFormat('dd MMM yyyy', 'bn').format(date);
    }
    if (diff.inDays >= 1) {
      return '${diff.inDays} দিন আগে';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} ঘণ্টা আগে';
    }
    if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} মিনিট আগে';
    }
    return 'এইমাত্র';
  }

  static String short(DateTime date) => DateFormat('dd MMM').format(date);
  static String full(DateTime date) => DateFormat('dd MMM yyyy').format(date);
  static String time(DateTime date) => DateFormat('hh:mm a').format(date);
}

class AppNumber {
  AppNumber._();

  static String compact(double value) {
    if (value.abs() >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(1)} কোটি';
    }
    if (value.abs() >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)} লক্ষ';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)} হাজার';
    }
    return value.toStringAsFixed(0);
  }

  static String money(double value) {
    final formatter = NumberFormat.currency(
      locale: 'bn_BD',
      symbol: '৳',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  static String percent(double value) => '${value.toStringAsFixed(0)}%';
}
