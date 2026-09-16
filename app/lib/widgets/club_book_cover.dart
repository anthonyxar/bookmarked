import 'package:flutter/material.dart';

class ClubBookCover extends StatelessWidget {
  final String title;
  final String coverColor;
  final String? coverUrl;
  final double width;
  final double height;
  const ClubBookCover({super.key, required this.title, required this.coverColor, this.coverUrl, this.width = 44, this.height = 64});

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(coverColor.replaceFirst('#', '0xFF')));
    final words = title.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
    final placeholder = Container(
      width: width,
      height: height,
      color: color,
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(color: Colors.white, fontSize: width / 4, fontWeight: FontWeight.w700)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: coverUrl != null
          ? Image.network(coverUrl!, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder)
          : placeholder,
    );
  }
}
