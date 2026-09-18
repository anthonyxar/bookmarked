// Mirrors the retired backend's ALLOWED_AVATAR_TYPES/ALLOWED_CLUB_IMAGE_TYPES
// and MAX_AVATAR_BYTES/MAX_CLUB_IMAGE_BYTES (backend/app/routers/users.py,
// clubs.py) — both used the same JPEG/PNG/WEBP/GIF, 5MB limit.
const allowedImageContentTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
};

const maxImageBytes = 5 * 1024 * 1024;

String contentTypeForFilename(String filename) {
  final extension = filename.split('.').last.toLowerCase();
  return allowedImageContentTypes[extension] ?? 'application/octet-stream';
}

/// Returns a user-facing message if [filename]/[byteLength] fail the same
/// checks Storage Security Rules enforce server-side, or null if valid.
/// Client-side so a bad pick fails fast, without a wasted upload attempt.
String? imageValidationError(String filename, int byteLength) {
  final extension = filename.split('.').last.toLowerCase();
  if (!allowedImageContentTypes.containsKey(extension)) {
    return 'Please choose a JPEG, PNG, WEBP, or GIF image';
  }
  if (byteLength > maxImageBytes) {
    return 'Image must be under 5MB';
  }
  return null;
}
