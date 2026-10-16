import 'package:go_router/go_router.dart';

import 'email_code_args.dart';
import 'email_code_screen.dart';
import 'email_forgot_screen.dart';
import 'email_sign_in_screen.dart';

/// Children of `/login`: `/login/email`, `.../forgot`, `.../code`. Sign-up
/// (`.../new`, `EmailSignUpScreen`) is not routed: the UI is hidden, the
/// screen and the server route stay.
/// The router's redirect treats every `/login/…` path as the login page.
final emailAuthRoutes = <RouteBase>[
  GoRoute(
    path: 'email',
    builder: (_, _) => const EmailSignInScreen(),
    routes: [
      GoRoute(
        path: 'forgot',
        builder: (_, state) =>
            EmailForgotScreen(initialEmail: state.extra as String?),
      ),
      GoRoute(
        path: 'code',
        // The arguments exist only in memory; a restored route without them
        // has no code to confirm, so it falls back to the sign-in step.
        redirect: (_, state) =>
            state.extra is EmailCodeArgs ? null : '/login/email',
        builder: (_, state) =>
            EmailCodeScreen(args: state.extra! as EmailCodeArgs),
      ),
    ],
  ),
];
