// HomePage, uygulamanın ana sayfasıdır. Quiz kategorilerini listeler ve kullanıcıya hoş geldin mesajı gösterir.
// Supabase bağlantı durumunu kontrol eder ve kategorileri buna göre görüntüler.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/base_page.dart';
import '../models/quiz_category.dart';
import '../services/supabase_service.dart';

// Stateless widget olarak ana sayfa çerçevesi
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const BasePage(title: 'Ana Sayfa', content: _HomePageContent());
  }
}

// Ana sayfa içeriğini yöneten stateful widget
class _HomePageContent extends StatefulWidget {
  const _HomePageContent();

  @override
  State<_HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<_HomePageContent> {
  // Kullanıcı bilgisi ve Supabase bağlantı durumu için state değişkenleri
  String _username = '';
  final SupabaseService _supabaseService = SupabaseService();
  bool _isSupabaseConnected = false;

  @override
  void initState() {
    super.initState();
    _getUsernameFromPrefs(); // Kullanıcı adını local storage'dan al
    _testSupabaseConnection(); // Supabase bağlantısını test et
  }

  // Supabase bağlantısını test eden metod
  Future<void> _testSupabaseConnection() async {
    try {
      final isConnected = await _supabaseService.testConnection();
      setState(() {
        _isSupabaseConnected = isConnected;
      });
      if (isConnected) {
        debugPrint('Supabase bağlantısı başarılı! Veriler çekilebilir.');
      } else {
        debugPrint('Supabase bağlantısı başarısız!');
      }
    } catch (e) {
      debugPrint('Supabase bağlantı testi hatası: $e');
    }
  }

  // SharedPreferences'dan kullanıcı adını alan metod
  // E-posta adresinden @ işaretinden önceki kısmı kullanıcı adı olarak kullanır
  Future<void> _getUsernameFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? 'Quiz Lover';
    final displayName = email.split('@').first;

    setState(() {
      _username = displayName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hoş geldin kartı - Kullanıcı adı ve uygulama durumu gösterilir
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.map, size: 60, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  'Merhaba $_username!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isSupabaseConnected
                      ? 'Şehirlerimiz ve dünya coğrafyası hakkındaki bilgilerini test etmeye hazır mısın?'
                      : 'Supabase bağlantısı kurulamadı. Lütfen internet bağlantınızı kontrol edin.',
                  style: TextStyle(
                    fontSize: 16,
                    color: _isSupabaseConnected ? null : Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Kategori başlığı
          const Text(
            'KATEGORİLER',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 8),
          // Supabase bağlantı durumuna göre kategori listesi veya hata mesajı
          if (_isSupabaseConnected)
            ...QuizCategories.allCategories.map(
              (category) => _buildCategoryCard(context, category),
            )
          else
            Container(
              // Bağlantı hatası mesajı
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: const Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 8),
                  Text(
                    'Supabase bağlantısı kurulamadı',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Kategoriler ve sorular yüklenemedi. Lütfen internet bağlantınızı kontrol edin.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Önceki skorlar butonu
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/scores');
            },
            icon: const Icon(Icons.scoreboard),
            label: const Text(
              'Önceki Skorlarım',
              style: TextStyle(fontSize: 16),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Kategori kartı widget'ını oluşturan yardımcı metod
  // Her kategori için tıklanabilir bir kart oluşturur
  Widget _buildCategoryCard(BuildContext context, QuizCategory category) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/quiz',
            arguments: {'category': category.id},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _getCategoryIcon(category.iconName),
                  color: Colors.blue,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  // Kategori ikonlarını string değerden IconData'ya çeviren yardımcı metod
  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'directions_car':
        return Icons.directions_car;
      case 'map':
        return Icons.map;
      case 'star':
        return Icons.star;
      case 'account_balance':
        return Icons.account_balance;
      case 'public':
        return Icons.public;
      default:
        return Icons.quiz;
    }
  }
}
