/// True when a body is the vault's own stand-in rather than text it actually
/// opened — an empty ciphertext-only row, a locked vault, or a failed decrypt.
///
/// Anything that re-sends a body has to check it, or the placeholder string
/// itself gets sent as the message: a retry of a failed encrypted send, and a
/// forward, which re-seals the plaintext for every destination.
bool isVaultPlaceholderBody(String body) =>
    body.isEmpty ||
    body == 'Encrypted message' ||
    body == 'Unable to decrypt this message';
