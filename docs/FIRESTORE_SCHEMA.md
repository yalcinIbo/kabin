# Kabin — Veri şeması

## Firestore
| Yol | Önemli alanlar | Yazan |
|---|---|---|
| `users/{uid}` | `displayName, email, credits, heightCm?, weightKg?, bodyType?, gender, consent{kvkkVersion,kvkkAccepted,aiTransferAccepted,acceptedAt}` | istemci oluşturur (`credits==0`); `credits` yalnız sunucu |
| `users/{uid}/usage/{yyyyMMdd}` | `tryon, model3d, avatar, analysis` sayaçları (TR saati) | sunucu |
| `users/{uid}/ledger/{id}` | `type(grant/debit/refund/purchase), amount, balanceAfter, jobType, jobId, note` · id: `welcome`, `debit_{jobId}`, `refund_{jobId}[_multiview]`, `grant_{ts}` | sunucu |
| `users/{uid}/photos/{id}` | `source(upload/generated), status(pending/processing/ready/rejected/failed), storagePath, thumbPath, qc{passed,blocked,issues,hintTr}, isDefault, avatarParams?` | yükleme: istemci (`pending`); gerisi sunucu |
| `users/{uid}/garments/{id}` | `status(analyzing/ready/failed), storagePath, thumbPath, isolatedPath?, analysis{category,garmentPhotoType,dominantColorHex,colorNameTr,fabricGuess,titleTr,descriptionTr,isIsolated,confidence}, tryonSupported, userEdited` | istemci oluşturur/düzeltir; analiz sunucu |
| `users/{uid}/tryons/{jobId}` | `status(queued/processing/done/failed), stage, progress, provider, options{multiView}, cost, costBreakdown, refundedAmount, refunded, results[{provider,angle,storagePath,width,height}], thumbPath, styleAdvice, error{code,messageTr}, model3dRequestId, model3dId, leaseUntil` | yalnız sunucu (istemci okur, bitmişi siler) |
| `users/{uid}/models3d/{id}` | `status, stage, progress, tryonId, sourcePath, provider, glbPath, previewPath, fileSizeBytes, cost, refunded, error, leaseUntil` | yalnız sunucu |
| `config/pricing` | `tryon, multiView, model3d, avatar, welcome, dailyCaps{tryon,model3d,avatar,analysis}` | konsol/seed |
| `config/flags` | `tryonEnabled, model3dEnabled, avatarEnabled` (acil durdurma anahtarı) | konsol/seed |
| `benchmarks/{runId}` + `/pairs/{pairId}` | `providers, pairCount, doneCount` · `status, results{fashn,vertex:{storagePath,ms,costUsd,error}}, rating{winner}` | sunucu; yönetici okur/puanlar |

İndeksler (`firestore.indexes.json`): collection-group `tryons`, `models3d`, `photos` için `(status, leaseUntil)` — süpürücü.

## Storage
| Yol | Yazan |
|---|---|
| `users/{uid}/photos/{id}/original.jpg`, `thumb.jpg` | istemci |
| `users/{uid}/photos/{id}/studio.jpg`, `thumb.jpg` (avatar) | sunucu |
| `users/{uid}/tmp/{uuid}.jpg` (selfie, üretimden sonra silinir) | istemci |
| `users/{uid}/garments/{id}/original.jpg`, `thumb.jpg` | istemci |
| `users/{uid}/garments/{id}/isolated.png` (Vertex için arka plan silinmiş) | sunucu |
| `users/{uid}/tryons/{jobId}/{provider}_{front|side|back}.jpg`, `thumb.jpg` | sunucu |
| `users/{uid}/models3d/{id}/model.glb`, `preview.jpg`, `isolated.png` | sunucu |
| `benchmarks/{runId}/{pairId}/{provider}.jpg` | sunucu |

Belge silinince ilgili klasörü `onXDeleted` tetikleyicileri temizler. Hesap silme: `deleteMyAccount` → `recursiveDelete(users/{uid})` + `users/{uid}/` önekli tüm dosyalar + Auth hesabı.

## Güvenlik kuralları (özet)
- Her şey kullanıcıya özel (`isOwner`); başka kullanıcının verisi okunamaz.
- İstemci: profil (kredisiz), fotoğraf (`pending/upload`), kıyafet (`analyzing`) oluşturur; kıyafet analizini yalnız izinli alanlarla düzeltir.
- `tryons`, `models3d`, `ledger`, `usage` istemciden yazılamaz; aktif iş silinemez.
- Storage: ham görseller yalnız sahibine (≤10 MB görsel); sunucu çıktıları istemciden yazılamaz.
- Testler: `functions/test/rules.test.ts`.
