import 'package:flutter/material.dart';

class NoteDetailScreen extends StatelessWidget {
  final Map<String, dynamic> note;
  const NoteDetailScreen({super.key, required this.note});

  Widget _buildSentimentBadge(String? sentiment) {
    if (sentiment == null || sentiment.isEmpty) return const SizedBox.shrink();

    Color bgColor;
    IconData icon;
    switch (sentiment.toLowerCase()) {
      case 'positive':
        bgColor = Colors.green.withValues(alpha: 0.2);
        icon = Icons.sentiment_satisfied_alt;
        break;
      case 'negative':
        bgColor = Colors.red.withValues(alpha: 0.2);
        icon = Icons.sentiment_dissatisfied;
        break;
      case 'neutral':
      default:
        bgColor = Colors.grey.withValues(alpha: 0.2);
        icon = Icons.sentiment_neutral;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            sentiment,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic>? categories = note['categories'];
    final String? sentiment = note['sentiment'];

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: const Text(
          'Thought Detail',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meta Row: Sentiment + Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSentimentBadge(sentiment),
                  Text(
                    note['created_at'].toString().split('T')[0],
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // The Thought Content
              Text(
                note['content'] ?? '',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Categories Section
              if (categories != null && categories.isNotEmpty) ...[
                const Text(
                  'Insights',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '#${cat.toString()}',
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
