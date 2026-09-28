/** Basit `--anahtar değer` / `--bayrak` argüman ayrıştırıcı. */
export function parseArgs(argv = process.argv.slice(2)): Record<string, string | boolean> {
  const out: Record<string, string | boolean> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next !== undefined && !next.startsWith('--')) {
      out[key] = next;
      i++;
    } else {
      out[key] = true;
    }
  }
  return out;
}

/** Emülatör ortam değişkenlerini (yoksa) varsayılanlara ayarlar. Modüller import edilmeden önce çağrılmalı. */
export function useEmulatorEnv(projectId: string, bucket: string): void {
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
  process.env.FIREBASE_STORAGE_EMULATOR_HOST ??= '127.0.0.1:9199';
  process.env.GCLOUD_PROJECT ??= projectId;
  process.env.STORAGE_BUCKET ??= bucket;
}
