import 'package:flutter/material.dart';

/// A simplified, dependency-free stand-in for the Google "G" mark —
/// four brand-colored quadrants behind a white disc with a bold "G".
class GoogleMark extends StatelessWidget {
  final double size;

  const GoogleMark({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: Container(color: const Color(0xFFEA4335))),
                        Expanded(child: Container(color: const Color(0xFFFBBC05))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: Container(color: const Color(0xFF4285F4))),
                        Expanded(child: Container(color: const Color(0xFF34A853))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          Text(
            'G',
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4285F4),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
