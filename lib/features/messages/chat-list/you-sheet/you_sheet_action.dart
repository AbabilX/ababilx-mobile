/// A deferred action selected in the account sheet.
///
/// The caller performs it only after the bottom sheet has fully closed. This
/// prevents a scanner sheet being pushed while the account sheet is popping.
enum YouSheetAction { scanQrLogin }
