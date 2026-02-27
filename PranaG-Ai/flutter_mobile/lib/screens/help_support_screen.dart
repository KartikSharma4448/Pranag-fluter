import "package:flutter/material.dart";

import "../theme/app_colors.dart";

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _openFaqIndex;

  final List<_FaqItem> _faqs = const [
    _FaqItem(
      question: "How does hardware-less detection work?",
      questionHint: "Hindi: Hardware-rahit detection kaise kaam karta hai?",
      answer:
          "PRANA-G AI uses your smartphone camera and microphone to capture biometric data, "
          "analyze gait patterns, and process vocalizations. TinyML models run on-device, "
          "eliminating the need for collars or ear tags.",
    ),
    _FaqItem(
      question: "Is internet required for diagnostics?",
      questionHint: "Hindi: Nidan ke liye internet avashyak hai?",
      answer:
          "No. Enable Offline Mode in Settings to use TinyML Edge processing. "
          "All AI diagnostics run locally and data syncs when you reconnect.",
    ),
    _FaqItem(
      question: "How accurate is the Muzzle-ID recognition?",
      questionHint: "Hindi: Muzzle-ID pehchan kitni sahi hai?",
      answer:
          "Muzzle-ID accuracy is comparable to human fingerprints. Each cow's nose pattern "
          "is unique and remains stable throughout its lifetime.",
    ),
    _FaqItem(
      question: "What diseases can be detected 48 hours early?",
      questionHint: "Hindi: Kaun si bimariyan 48 ghante pehle detect hoti hain?",
      answer:
          "Mastitis, Ketosis, Lameness, Respiratory infections, and Heat stress. "
          "Acoustic AI detects subtle changes before visible symptoms.",
    ),
    _FaqItem(
      question: "Does PRANA-G support my language?",
      questionHint: "Hindi: Kya PRANA-G meri bhasha support karta hai?",
      answer:
          "Yes. Via Bhashini integration, we support 22+ Indian languages. "
          "All diagnostics can be heard via voice output.",
    ),
  ];

  final List<_SupportChannel> _supportChannels = const [
    _SupportChannel(
      label: "Call Us",
      value: "1800-123-PRANA",
      icon: Icons.call,
      color: Color(0xFFDCFCE7),
      iconColor: Color(0xFF16A34A),
    ),
    _SupportChannel(
      label: "WhatsApp",
      value: "+91 98765 00000",
      icon: Icons.chat_bubble_outline,
      color: Color(0xFFDBEAFE),
      iconColor: Color(0xFF2563EB),
    ),
    _SupportChannel(
      label: "Email",
      value: "support@prana-g.ai",
      icon: Icons.mail_outline,
      color: Color(0xFFF3E8FF),
      iconColor: Color(0xFF7C3AED),
    ),
  ];

  final List<_ResourceItem> _resources = const [
    _ResourceItem(
      title: "User Guide",
      description: "Complete step-by-step manual",
      icon: Icons.menu_book,
    ),
    _ResourceItem(
      title: "Video Tutorials",
      description: "Learn with visual demonstrations",
      icon: Icons.play_circle_outline,
    ),
    _ResourceItem(
      title: "Audio Instructions",
      description: "Voice-guided help for all features",
      icon: Icons.volume_up,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Help & Support",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "We're here to help you",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.help_outline, color: AppColors.primary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildQuickContact(),
            const SizedBox(height: 16),
            _buildContactCard(),
            const SizedBox(height: 16),
            _buildFaqs(),
            const SizedBox(height: 16),
            _buildResources(),
            const SizedBox(height: 16),
            _buildFeedbackCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickContact() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Need Immediate Help?",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Our support team is available 24/7",
            style: TextStyle(fontSize: 12, color: Color(0xCCFFFFFF)),
          ),
          const SizedBox(height: 16),
          Row(
            children: _supportChannels
                .map(
                  (channel) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Icon(channel.icon, color: AppColors.white, size: 22),
                              const SizedBox(height: 6),
                              Text(
                                channel.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Contact Information",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          ..._supportChannels.map(
            (channel) => _ContactRow(channel: channel),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Frequently Asked Questions",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 10),
        ..._faqs.asMap().entries.map((entry) {
          final index = entry.key;
          final faq = entry.value;
          final isOpen = _openFaqIndex == index;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _openFaqIndex = isOpen ? null : index;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                faq.question,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                faq.questionHint,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 200),
                          turns: isOpen ? 0.5 : 0.0,
                          child: const Icon(Icons.expand_more, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOpen)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      faq.answer,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResources() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Learning Resources",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 10),
        ..._resources.map(
          (resource) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(resource.icon, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resource.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            resource.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textLight),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3C4), Color(0xFFFFE8A3)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Send Feedback",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB45309),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Help us improve PRANA-G AI by sharing your experience and suggestions.",
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {},
            child: const Text(
              "Submit Feedback",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({
    required this.question,
    required this.questionHint,
    required this.answer,
  });

  final String question;
  final String questionHint;
  final String answer;
}

class _SupportChannel {
  const _SupportChannel({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconColor;
}

class _ResourceItem {
  const _ResourceItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.channel});

  final _SupportChannel channel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: channel.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(channel.icon, color: channel.iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.value,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.borderLight),
      ],
    );
  }
}
