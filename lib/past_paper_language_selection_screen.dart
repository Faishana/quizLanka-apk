import 'package:flutter/material.dart';
import 'package:quiz_lanka/PastPaperListScreen.dart';
import 'package:quiz_lanka/QL.dart';

const Color _pageBg = Color(0xFFF1F5FC);

class PastPaperLanguageSelectionScreen extends StatelessWidget {
  final int subjectId;
  final String subjectName;
  final String category;

  const PastPaperLanguageSelectionScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.category,
  });

  void _openPastPapers(BuildContext context, String medium) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PastPaperListScreen(
          subjectId: subjectId,
          subjectName: subjectName,
          category: category,
          medium: medium,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose language',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: QL.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select the language of the past paper you want to practise.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: QL.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _LanguageCard(
                    language: 'Sinhala',
                    subtitle: 'සිංහල මාධ්‍ය',
                    code: 'si',
                    glyph: 'සි',
                    onTap: () => _openPastPapers(context, 'si'),
                  ),
                  const SizedBox(height: 12),
                  _LanguageCard(
                    language: 'English',
                    subtitle: 'English medium',
                    code: 'en',
                    glyph: 'En',
                    onTap: () => _openPastPapers(context, 'en'),
                  ),
                  const SizedBox(height: 12),
                  _LanguageCard(
                    language: 'Tamil',
                    subtitle: 'தமிழ் மொழி மூலம்',
                    code: 'ta',
                    glyph: 'த',
                    onTap: () => _openPastPapers(context, 'ta'),
                  ),
                  const SizedBox(height: 24),
                  const _InfoCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [QL.navy, QL.navyDeep],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 170,
                height: 170,
                decoration: const BoxDecoration(
                  color: QL.navyLight,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Back',
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: QL.navyDeep,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: QL.gold,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.translate_rounded,
                            color: QL.navy,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Past papers',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        subjectName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text(
                        'Choose your preferred medium',
                        style: TextStyle(color: QL.ice, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: QL.blue, size: 21),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Past papers are shown based on the selected language. '
              'Some questions may include diagrams or images.',
              style: TextStyle(fontSize: 13, color: QL.muted, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String language;
  final String subtitle;
  final String code;
  final String glyph;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.language,
    required this.subtitle,
    required this.code,
    required this.glyph,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$language medium',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCE4F4)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12123066),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: QL.navy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  glyph,
                  style: const TextStyle(
                    color: QL.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: QL.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: QL.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code.toUpperCase(),
                  style: const TextStyle(
                    color: QL.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF0FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: QL.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
