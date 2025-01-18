import 'package:flutter/material.dart';
import 'dart:io';

class QuickAccessBar extends StatelessWidget {
  final Function(String) onPathSelected;

  const QuickAccessBar({super.key, required this.onPathSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _quickAccessButton(
                context,
                'Masaüstü',
                Icons.desktop_windows,
                '${Platform.environment['USERPROFILE']}\\Desktop',
              ),
              const SizedBox(width: 8),
              _quickAccessButton(
                context,
                'İndirilenler',
                Icons.download,
                '${Platform.environment['USERPROFILE']}\\Downloads',
              ),
              const SizedBox(width: 8),
              _quickAccessButton(
                context,
                'Belgeler',
                Icons.folder,
                '${Platform.environment['USERPROFILE']}\\Documents',
              ),
              const SizedBox(width: 8),
              _quickAccessButton(
                context,
                'Resimler',
                Icons.image,
                '${Platform.environment['USERPROFILE']}\\Pictures',
              ),
              const SizedBox(width: 8),
              _quickAccessButton(
                context,
                'Videolar',
                Icons.video_library,
                '${Platform.environment['USERPROFILE']}\\Videos',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAccessButton(
    BuildContext context,
    String label,
    IconData icon,
    String path,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onPathSelected(path),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
} 