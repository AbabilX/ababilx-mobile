/// Sent as `X-APP-KEY` on `/auth/email/*` and `/auth/device/*` only.
/// Hardcoded: it ships in the APK either way, so it is bot friction, not a
/// secret. Must equal the API's ABABILX_APP_KEY;
/// `--dart-define=ABABILX_APP_KEY=…` still overrides it.
const ababilxAppKey = String.fromEnvironment(
  'ABABILX_APP_KEY',
  defaultValue:
      '878c6721d52f43c7e6a781bb33dceaf4f96c2484259e9dd4ef967a90889911f3',
);
