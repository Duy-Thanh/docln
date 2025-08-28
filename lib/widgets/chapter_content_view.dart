import 'package:flutter/material.dart';

class ChapterContentView extends StatelessWidget {
  final String content;
  final ScrollController? scrollController;

  const ChapterContentView({
    Key? key,
    required this.content,
    this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chapter content
          SelectableText(
            content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
              fontSize: 16,
            ),
            textAlign: TextAlign.justify,
          ),

          // Bottom spacing
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
