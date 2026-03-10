import 'package:flutter/material.dart';

const pageAccents = [
  Color(0xFF9b8aff), // Insights — purple
  Color(0xFF60a5fa), // Loops — blue
  Color(0xFF4ade80), // Health — green
  Color(0xFFf472b6), // Music — pink
  Color(0xFF2979FF), // Pipeline — indigo
];

const pageLabels = ['Insights', 'Loops', 'Health', 'Music', 'Pipeline'];

class PageIndicator extends StatelessWidget {
  final int currentPage;
  final int pageCount;

  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (index) {
              final isActive = index == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: isActive ? 16 : 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isActive ? pageAccents[index] : Colors.white12,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            pageLabels[currentPage],
            style: TextStyle(
              color: pageAccents[currentPage],
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
