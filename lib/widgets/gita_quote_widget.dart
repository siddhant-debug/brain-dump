import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/theme_provider.dart';
import '../features/notes/providers/gita_provider.dart';

class GitaQuote {
  final String sanskrit;
  final String english;
  final String hindi;
  final String reference;

  const GitaQuote({
    required this.sanskrit,
    required this.english,
    required this.hindi,
    required this.reference,
  });
}

class GitaQuoteWidget extends ConsumerWidget {
  const GitaQuoteWidget({super.key});

  static const List<GitaQuote> _quotes = [
    GitaQuote(
      sanskrit: 'कर्मण्येवाधिकारस्ते मा फलेषु कदाचन।\nमा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि॥',
      english: 'You have a right to perform your prescribed duties, but you are not entitled to the fruits of your actions.',
      hindi: 'कर्म करो, फल की चिंता मत करो।',
      reference: 'Bhagavad Gita · 2.47',
    ),
    GitaQuote(
      sanskrit: 'योगस्थः कुरु कर्माणि सङ्गं त्यक्त्वा धनञ्जय।\nसिद्ध्यसिद्ध्योः समो भूत्वा समत्वं योग उच्यते॥',
      english: 'Be steadfast in yoga, O Arjuna. Perform your duty and abandon all attachment to success or failure. Such evenness of mind is called yoga.',
      hindi: 'समभाव में स्थिर होकर कर्म करो — यही योग है।',
      reference: 'Bhagavad Gita · 2.48',
    ),
    GitaQuote(
      sanskrit: 'नैनं छिन्दन्ति शस्त्राणि नैनं दहति पावकः।\nन चैनं क्लेदयन्त्यापो न शोषयति मारुतः॥',
      english: 'The soul can never be cut into pieces by any weapon, nor burned by fire, nor moistened by water, nor withered by the wind.',
      hindi: 'आत्मा अजर, अमर और अविनाशी है।',
      reference: 'Bhagavad Gita · 2.23',
    ),
    GitaQuote(
      sanskrit: 'श्रेयान्स्वधर्मो विगुणः परधर्मात्स्वनुष्ठितात्।\nस्वधर्मे निधनं श्रेयः परधर्मो भयावहः॥',
      english: 'It is better to perform one\'s own duties imperfectly than to master the duties of another. Better to die in one\'s own dharma than in the dharma of another.',
      hindi: 'अपना अधूरा धर्म किसी दूसरे के पूर्ण धर्म से श्रेष्ठ है।',
      reference: 'Bhagavad Gita · 3.35',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;
    final gitaState = ref.watch(gitaProvider);
    
    final quote = _quotes[gitaState.index % _quotes.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "REFLECT",
                style: AppTextStyles.label(colors.textDim.withValues(alpha: 0.5)).copyWith(
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () => ref.read(gitaProvider.notifier).refresh(),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 10,
                      color: colors.textDim.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            quote.sanskrit,
            style: AppTextStyles.serifBody(colors.text).copyWith(
              fontSize: 15,
              height: 1.7,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            quote.english,
            style: AppTextStyles.body(colors.textDim).copyWith(
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            quote.hindi,
            style: AppTextStyles.micro(colors.textDim.withValues(alpha: 0.5)).copyWith(
              height: 1.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            quote.reference.toUpperCase(),
            style: AppTextStyles.label(colors.textDim.withValues(alpha: 0.3)).copyWith(
              fontSize: 8,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
