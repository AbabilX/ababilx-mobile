/// Snippet wording, English and Bangla. Kept beside the feature: the shared
/// translations file is far past the size any one file should be.
class SnippetStrings {
  const SnippetStrings(this.bangla);

  factory SnippetStrings.of(String language) =>
      SnippetStrings(language == 'bn');

  final bool bangla;

  String _t(String en, String bn) => bangla ? bn : en;

  String get chip => _t('Snippet', 'স্নিপেট');
  String get createTitle => _t('Create snippet', 'স্নিপেট তৈরি করুন');
  String get titleLabel => _t('Title (optional)', 'শিরোনাম (ঐচ্ছিক)');
  String get typeLabel => _t('Type', 'ধরন');
  String get markdown => _t('Markdown (.md)', 'মার্কডাউন (.md)');
  String get plainText => _t('Plain text (.txt)', 'সাধারণ লেখা (.txt)');
  String get contentHint =>
      _t('Paste or type the content', 'লেখা পেস্ট করুন বা টাইপ করুন');
  String get messageHint =>
      _t('Add a message if you like', 'চাইলে একটি বার্তা যোগ করুন');
  String get send => _t('Send', 'পাঠান');
  String get sending => _t('Sending…', 'পাঠানো হচ্ছে…');
  String get empty => _t('Add some content first.', 'আগে কিছু লেখা যোগ করুন।');
  String get tooLarge => _t(
    'This snippet is too large. The limit is 10 MB.',
    'এই স্নিপেটটি খুব বড়। সীমা ১০ এমবি।',
  );
  String get failed =>
      _t('Could not send the snippet.', 'স্নিপেট পাঠানো যায়নি।');
  String get discardTitle =>
      _t('Discard this snippet?', 'স্নিপেটটি বাদ দেবেন?');
  String get discard => _t('Discard', 'বাদ দিন');
  String get keepEditing => _t('Keep editing', 'লিখতে থাকুন');
  String get copied => _t('Copied', 'কপি হয়েছে');
  String get copy => _t('Copy', 'কপি');
  String get showSource => _t('Show source', 'সোর্স দেখুন');
  String get showFormatted => _t('Show formatted', 'ফরম্যাট করা দেখুন');
  String get unreadable =>
      _t('Could not read this file.', 'ফাইলটি পড়া যায়নি।');
  String get sourceOnly => _t(
    'Too large to format. Showing the source.',
    'ফরম্যাট করার জন্য খুব বড়। সোর্স দেখানো হচ্ছে।',
  );
  String get tooLongTitle =>
      _t('This message is too long', 'বার্তাটি অনেক বড়');
  String get tooLongBody => _t(
    'A message can carry 6000 words. Send this text as a snippet instead: '
        'it goes as a file the other person can open and read.',
    'একটি বার্তায় সর্বোচ্চ ৬০০০ শব্দ পাঠানো যায়। লেখাটি স্নিপেট হিসেবে পাঠান: '
        'এটি একটি ফাইল হয়ে যাবে, যা অন্যজন খুলে পড়তে পারবেন।',
  );
  String get tapToOpen => _t('Tap to open', 'খুলতে ট্যাপ করুন');
  String get snippets => _t('Snippets', 'স্নিপেট');
  String get listEmptyTitle => _t('No snippets yet', 'এখনো কোনো স্নিপেট নেই');
  String get listEmptyBody => _t(
    'Send long text as a snippet from the + menu. Every snippet in this chat '
        'shows up here.',
    'এই চ্যাটের + মেনু থেকে বড় লেখা স্নিপেট হিসেবে পাঠান। এই চ্যাটের সব স্নিপেট এখানে দেখা যাবে।',
  );
  String get listFailed =>
      _t('Could not load snippets.', 'স্নিপেট লোড করা যায়নি।');
  String get loadMore => _t('Load more', 'আরও দেখুন');
  String get retry => _t('Try again', 'আবার চেষ্টা করুন');
}
