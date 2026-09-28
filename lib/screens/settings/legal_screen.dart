import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// KVKK aydınlatma metni (özet). Yayına çıkmadan önce hukuki danışmanla nihai hâli verilmelidir.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const _sections = <(String, String)>[
    ('Veri sorumlusu', 'Kabin uygulaması. İletişim: ${AppConstants.supportEmail}'),
    (
      'İşlenen veriler',
      'Hesap bilgilerin (e-posta, ad), yüklediğin boydan fotoğraflar ve selfie\'ler, kıyafet fotoğrafları, '
          'isteğe bağlı olarak boy, kilo, vücut tipi ve cinsiyet bilgin, kredi hareketlerin.',
    ),
    (
      'İşleme amacı',
      'Sanal deneme görselleri, yan/arka görünümler, 3D model ve stil/beden önerileri üretmek; fotoğraf kalite kontrolü '
          'yapmak; kredi bakiyeni yönetmek; hizmetin güvenliğini sağlamak.',
    ),
    (
      'Yurt dışına aktarım',
      'Görsellerin, işleme amacıyla sınırlı olmak üzere yurt dışında bulunan yapay zekâ hizmet sağlayıcılarına aktarılır: '
          'Google (Gemini API, Vertex AI — ABD/AB), fal.ai (ABD). Aktarım açık rızana dayanır; rızanı istediğin an geri alabilirsin.',
    ),
    (
      'Saklama süresi',
      'Verilerin hesabın açık olduğu sürece saklanır. Selfie\'ler stüdyo fotoğrafı üretildikten sonra silinir. '
          'Bir fotoğrafı, kıyafeti veya denemeyi sildiğinde ilgili dosyalar da silinir.',
    ),
    (
      'Hakların',
      'KVKK m.11 kapsamında verilerine erişme, düzeltme, silme ve itiraz haklarına sahipsin. '
          'Ayarlar > "Hesabımı ve verilerimi sil" ile tüm verilerini kalıcı olarak silebilirsin.',
    ),
    ('Çocuklar', '18 yaşından küçüklerin fotoğrafları işlenmez; bu tür fotoğraflar otomatik olarak reddedilir.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('KVKK aydınlatma metni')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Sürüm ${AppConstants.kvkkVersion}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final (title, body) in _sections) ...[
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
