/// Names of the two surfaces that can want the Android ringtone.
///
/// Both are process-wide inside `call_ringer`, so a hold taken in the FCM
/// background isolate is released from the UI isolate and vice versa. Keep
/// them in sync with `MainActivity.FLUTTER_HOLDER`.
library;

/// CallKit's native incoming UI is showing.
const callRingHolderNative = 'native';

/// The in-app `/call` screen is showing.
const callRingHolderFlutter = 'flutter';
