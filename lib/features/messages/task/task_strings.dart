import 'task_card_data.dart';

/// Task card wording, English and Bangla, kept beside the feature.
class TaskStrings {
  const TaskStrings(this.bangla);

  factory TaskStrings.of(String language) => TaskStrings(language == 'bn');

  final bool bangla;

  String _t(String en, String bn) => bangla ? bn : en;

  String get chip => _t('Task', 'টাস্ক');
  String get cardLabel => _t('Task', 'টাস্ক');
  String get tasks => _t('Tasks', 'টাস্ক');
  String get createTitle => _t('New task', 'নতুন টাস্ক');
  String get titleLabel => _t('Title', 'শিরোনাম');
  String get descriptionHint =>
      _t('Describe the task (optional)', 'টাস্কের বিবরণ লিখুন (ঐচ্ছিক)');
  String get priority => _t('Priority', 'অগ্রাধিকার');
  String get status => _t('Status', 'অবস্থা');
  String get addPhoto => _t('Photo', 'ছবি');
  String get addFile => _t('File', 'ফাইল');
  String get send => _t('Send', 'পাঠান');
  String get uploading => _t('Uploading…', 'আপলোড হচ্ছে…');
  String get needTitle => _t('Give the task a title.', 'টাস্কের শিরোনাম দিন।');
  String get uploadFailed =>
      _t('Could not add that file.', 'ফাইলটি যোগ করা যায়নি।');
  String get updateFailed =>
      _t('Could not update the task.', 'টাস্ক আপডেট করা যায়নি।');
  String get discardTitle => _t('Discard this task?', 'টাস্কটি বাদ দেবেন?');
  String get discard => _t('Discard', 'বাদ দিন');
  String get keepEditing => _t('Keep editing', 'লিখতে থাকুন');
  String get all => _t('All', 'সব');
  String get open => _t('Open', 'চলমান');
  String get closed => _t('Closed', 'শেষ');
  String get emptyTitle => _t('No tasks yet', 'এখনো কোনো টাস্ক নেই');
  String get emptyBody => _t(
    'Send a task from the + menu in this chat. Every task you two share '
        'shows up here.',
    'এই চ্যাটের + মেনু থেকে টাস্ক পাঠান। আপনাদের দুজনের সব টাস্ক এখানে দেখা যাবে।',
  );
  String get emptyFilter => _t('Nothing here.', 'এখানে কিছু নেই।');
  String get loadFailed => _t('Could not load tasks.', 'টাস্ক লোড করা যায়নি।');
  String get retry => _t('Try again', 'আবার চেষ্টা করুন');
  String get fromYou => _t('From you', 'আপনার দেওয়া');
  String from(String name) => _t('From $name', '$name-এর দেওয়া');
  String get openInChat => _t('Show in chat', 'চ্যাটে দেখুন');

  String priorityName(TaskPriority p) => switch (p) {
    TaskPriority.low => _t('Low', 'কম'),
    TaskPriority.medium => _t('Medium', 'মাঝারি'),
    TaskPriority.high => _t('High', 'বেশি'),
    TaskPriority.urgent => _t('Urgent', 'জরুরি'),
  };

  String statusName(TaskStatus s) => switch (s) {
    TaskStatus.todo => _t('To do', 'করতে হবে'),
    TaskStatus.inProgress => _t('In progress', 'চলছে'),
    TaskStatus.review => _t('Review', 'রিভিউ'),
    TaskStatus.blocked => _t('Blocked', 'আটকে আছে'),
    TaskStatus.done => _t('Done', 'সম্পন্ন'),
    TaskStatus.cancelled => _t('Cancelled', 'বাতিল'),
  };

  /// The timeline line for a change. [actor] is "You" or a name.
  String statusChanged(String actor, TaskStatus s, String title) => _t(
    '$actor marked ${_named(title)} as ${statusName(s)}',
    '$actor ${_namedBn(title)} "${statusName(s)}" করেছেন',
  );

  String priorityChanged(String actor, TaskPriority p, String title) => _t(
    '$actor set the priority of ${_named(title)} to ${priorityName(p)}',
    '$actor ${_namedBn(title)}-এর অগ্রাধিকার "${priorityName(p)}" করেছেন',
  );

  String _named(String title) => title.isEmpty ? 'a task' : '"$title"';
  String _namedBn(String title) => title.isEmpty ? 'একটি টাস্ক' : '"$title"';
}
