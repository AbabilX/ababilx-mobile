import 'email_auth_repository.dart';

enum EmailCodePurpose { signUp, reset }

/// What the code screen needs to confirm a code and to ask for another.
///
/// A sign-up keeps its name and password here, in memory only, because the
/// server's resend is the sign-up request itself; nothing is written to disk.
class EmailCodeArgs {
  const EmailCodeArgs({
    required this.purpose,
    required this.email,
    required this.sent,
    this.name = '',
    this.password = '',
  });

  final EmailCodePurpose purpose;
  final String email;
  final EmailCodeSent sent;
  final String name;
  final String password;

  Future<EmailCodeSent> resend(EmailAuthRepository repo) =>
      purpose == EmailCodePurpose.signUp
      ? repo.signUp(name: name, email: email, password: password)
      : repo.requestReset(email: email);
}
