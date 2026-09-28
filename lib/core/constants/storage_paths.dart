/// Storage yolları. `functions/src/lib/paths.ts` (SP) ile birebir aynı tutulmalı.
abstract final class StoragePaths {
  static String photoOriginal(String uid, String photoId) => 'users/$uid/photos/$photoId/original.jpg';
  static String photoThumb(String uid, String photoId) => 'users/$uid/photos/$photoId/thumb.jpg';
  static String garmentOriginal(String uid, String garmentId) => 'users/$uid/garments/$garmentId/original.jpg';
  static String garmentThumb(String uid, String garmentId) => 'users/$uid/garments/$garmentId/thumb.jpg';
  static String tmpSelfie(String uid, String fileId) => 'users/$uid/tmp/$fileId.jpg';
}
