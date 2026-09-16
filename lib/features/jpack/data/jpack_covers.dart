import 'package:flutter/material.dart';

/// What is drawn on the upper half of a cover. Painted in code
/// (`jpack_cover_art.dart`), so a cover costs no asset and stays sharp.
enum CoverMotif {
  classic,
  eid,
  boishakh,
  birthday,
  wedding,
  congrats,
  thanks,
  victory,
}

class JPackCover {
  const JPackCover({
    required this.id,
    required this.nameKey,
    required this.motif,
    required this.top,
    required this.bottom,
    required this.flap,
    required this.accent,
    required this.ink,
    required this.messages,
    this.keywords = const [],
  });

  final String id;

  /// `AppTranslations` key for the cover's name.
  final String nameKey;
  final CoverMotif motif;

  /// Upper panel gradient.
  final Color top;
  final Color bottom;

  /// The lower flap the seal sits on.
  final Color flap;

  /// Seal and ornament colour.
  final Color accent;

  /// Text drawn over the upper panel.
  final Color ink;

  /// Ready-made messages by language code. `bn` is the default.
  final Map<String, List<String>> messages;

  /// Extra search words (both languages) beyond the translated name.
  final List<String> keywords;

  List<String> messagesFor(String lang) =>
      messages[lang] ?? messages['bn'] ?? const [];
}

const _gold = Color(0xFFF2CE8A);
const _red = Color(0xFFE8503F);

const jpackCovers = <JPackCover>[
  JPackCover(
    id: 'classic',
    nameKey: 'jpack_cover_classic',
    motif: CoverMotif.classic,
    top: Color(0xFFF0634F),
    bottom: Color(0xFFD9412F),
    flap: _red,
    accent: _gold,
    ink: Colors.white,
    keywords: ['classic', 'red', 'ক্লাসিক', 'লাল'],
    messages: {
      'bn': [
        'শুভেচ্ছা রইল',
        'অনেক অনেক ভালোবাসা',
        'তোমার জন্য ছোট্ট একটা উপহার',
        'সবসময় ভালো থেকো',
        'মিষ্টি খেয়ে নিও 😊',
      ],
      'en': [
        'Best wishes',
        'Lots of love',
        'A little gift for you',
        'Stay well, always',
        'Treat yourself 😊',
      ],
    },
  ),
  JPackCover(
    id: 'eid',
    nameKey: 'jpack_cover_eid',
    motif: CoverMotif.eid,
    top: Color(0xFF1F6E55),
    bottom: Color(0xFF0E4636),
    flap: Color(0xFF0B3A2D),
    accent: _gold,
    ink: Color(0xFFFFF4DC),
    keywords: ['eid', 'mubarak', 'salami', 'ঈদ', 'সালামি', 'মোবারক'],
    messages: {
      'bn': [
        'ঈদ মোবারক! ঈদের সালামি রইল',
        'ঈদের আনন্দ ছড়িয়ে পড়ুক সবার মাঝে',
        'তোমার ঈদ কাটুক খুশিতে',
        'ঈদ মোবারক, সালামিটা নিয়ে নাও 🌙',
      ],
      'en': [
        'Eid Mubarak! Here is your Eid salami',
        'May the joy of Eid reach everyone',
        'Have a joyful Eid',
        'Eid Mubarak, your salami is here 🌙',
      ],
    },
  ),
  JPackCover(
    id: 'boishakh',
    nameKey: 'jpack_cover_boishakh',
    motif: CoverMotif.boishakh,
    top: Color(0xFFFFF6EA),
    bottom: Color(0xFFF7E3C8),
    flap: Color(0xFFD7263D),
    accent: Color(0xFFFFD166),
    ink: Color(0xFFB0172B),
    keywords: ['boishakh', 'new year', 'noboborsho', 'বৈশাখ', 'নববর্ষ'],
    messages: {
      'bn': [
        'শুভ নববর্ষ!',
        'এসো হে বৈশাখ, এসো এসো',
        'নতুন বছর ভরে উঠুক আনন্দে',
        'বৈশাখের শুভেচ্ছা রইল',
      ],
      'en': [
        'Shubho Noboborsho!',
        'Welcome, Boishakh',
        'May the new year be full of joy',
        'Warm Pohela Boishakh wishes',
      ],
    },
  ),
  JPackCover(
    id: 'birthday',
    nameKey: 'jpack_cover_birthday',
    motif: CoverMotif.birthday,
    top: Color(0xFFFF8FB1),
    bottom: Color(0xFF9B6BFF),
    flap: Color(0xFF7A4FE0),
    accent: Color(0xFFFFE08A),
    ink: Colors.white,
    keywords: ['birthday', 'bday', 'জন্মদিন'],
    messages: {
      'bn': [
        'শুভ জন্মদিন! 🎂',
        'জন্মদিনের অনেক শুভেচ্ছা',
        'নতুন বছরটা হোক দারুণ',
        'কেক খাওয়ার টাকা পাঠালাম 🎉',
      ],
      'en': [
        'Happy birthday! 🎂',
        'Many happy returns of the day',
        'Have an amazing year ahead',
        'Cake money is on me 🎉',
      ],
    },
  ),
  JPackCover(
    id: 'wedding',
    nameKey: 'jpack_cover_wedding',
    motif: CoverMotif.wedding,
    top: Color(0xFF8E1B3A),
    bottom: Color(0xFF5A0F24),
    flap: Color(0xFF4A0B1D),
    accent: Color(0xFFE9C46A),
    ink: Color(0xFFFBE7C6),
    keywords: ['wedding', 'marriage', 'biye', 'বিয়ে', 'বিবাহ'],
    messages: {
      'bn': [
        'নতুন জীবনের শুভকামনা',
        'বিয়ের অনেক অনেক শুভেচ্ছা',
        'সারাজীবন একসাথে সুখে থেকো',
        'দুজনের জন্য ভালোবাসা রইল 💍',
      ],
      'en': [
        'Best wishes for your new life',
        'Congratulations on your wedding',
        'Happy together, forever',
        'Love to you both 💍',
      ],
    },
  ),
  JPackCover(
    id: 'congrats',
    nameKey: 'jpack_cover_congrats',
    motif: CoverMotif.congrats,
    top: Color(0xFF2EC4B6),
    bottom: Color(0xFF137A8C),
    flap: Color(0xFF0F5F6E),
    accent: Color(0xFFFFD166),
    ink: Colors.white,
    keywords: ['congrats', 'congratulations', 'result', 'অভিনন্দন', 'রেজাল্ট'],
    messages: {
      'bn': [
        'অভিনন্দন! দারুণ করেছো',
        'তোমার সাফল্যে আমরা গর্বিত',
        'এভাবেই এগিয়ে যাও',
        'মিষ্টিমুখ করাও এবার 🎉',
      ],
      'en': [
        'Congratulations! Well done',
        'So proud of you',
        'Keep going like this',
        'Time to celebrate 🎉',
      ],
    },
  ),
  JPackCover(
    id: 'thanks',
    nameKey: 'jpack_cover_thanks',
    motif: CoverMotif.thanks,
    top: Color(0xFF3FB68B),
    bottom: Color(0xFF1F7F62),
    flap: Color(0xFF186A52),
    accent: Color(0xFFFFF1C1),
    ink: Colors.white,
    keywords: ['thanks', 'thank you', 'ধন্যবাদ', 'কৃতজ্ঞতা'],
    messages: {
      'bn': [
        'অসংখ্য ধন্যবাদ',
        'তোমার সাহায্যের জন্য কৃতজ্ঞ',
        'পাশে থাকার জন্য ধন্যবাদ',
        'ছোট্ট একটা ধন্যবাদ 💚',
      ],
      'en': [
        'Thank you so much',
        'Grateful for your help',
        'Thanks for being there',
        'A small thank you 💚',
      ],
    },
  ),
  JPackCover(
    id: 'victory',
    nameKey: 'jpack_cover_victory',
    motif: CoverMotif.victory,
    top: Color(0xFF0B8A4E),
    bottom: Color(0xFF006A4E),
    flap: Color(0xFF00573F),
    accent: Color(0xFFF42A41),
    ink: Colors.white,
    keywords: ['victory', 'independence', 'bangladesh', 'বিজয়', 'স্বাধীনতা'],
    messages: {
      'bn': [
        'বিজয় দিবসের শুভেচ্ছা',
        'লাল-সবুজের শুভেচ্ছা রইল',
        'স্বাধীনতার আনন্দ সবার হোক',
        'জয় বাংলা 🇧🇩',
      ],
      'en': [
        'Happy Victory Day',
        'Red and green wishes to you',
        'Celebrating our freedom together',
        'Joy Bangla 🇧🇩',
      ],
    },
  ),
];

/// A received JPack may name a cover this build does not have; it still draws.
JPackCover jpackCoverById(String id) =>
    jpackCovers.firstWhere((c) => c.id == id, orElse: () => jpackCovers.first);
