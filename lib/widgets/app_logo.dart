import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const AppLogo({
    super.key,
    this.size = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.folder_open,
            color: Colors.white,
            size: size * 0.6,
          ),
          Positioned(
            right: size * 0.15,
            bottom: size * 0.15,
            child: Icon(
            Icons.cleaning_services,
            color: Colors.white,
            size: size * 0.4,
          ),
          ),
        ],
      ),
    );
  }
} 