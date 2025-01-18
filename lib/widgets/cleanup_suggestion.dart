import 'package:flutter/material.dart';

class CleanupSuggestion extends StatelessWidget {
  final String title;
  final String description;
  final int potentialSaving;
  final VoidCallback onClean;

  const CleanupSuggestion({
    super.key,
    required this.title,
    required this.description,
    required this.potentialSaving,
    required this.onClean,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cleaning_services),
        title: Text(title),
        subtitle: Text(description),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${(potentialSaving / 1024 / 1024).toStringAsFixed(1)} MB'),
            ElevatedButton(
              onPressed: onClean,
              child: const Text('Temizle'),
            ),
          ],
        ),
      ),
    );
  }
} 