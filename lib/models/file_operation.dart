import 'package:flutter/material.dart';

class FileOperation {
  final String type;
  final String path;
  final DateTime time;
  final bool success;
  
  FileOperation({
    required this.type,
    required this.path,
    required this.time,
    required this.success,
  });

  IconData get icon {
    switch (type) {
      case 'delete':
        return Icons.delete;
      case 'clean':
        return Icons.cleaning_services;
      case 'analyze':
        return Icons.analytics;
      default:
        return Icons.file_present;
    }
  }

  String get typeText {
    switch (type) {
      case 'delete':
        return 'Silme';
      case 'clean':
        return 'Temizlik';
      case 'analyze':
        return 'Analiz';
      default:
        return type;
    }
  }
} 