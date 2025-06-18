// ContactPage, kullanıcıların uygulama yöneticileriyle iletişime geçebilmelerini sağlayan bir form sayfasıdır.
// Bu sayfa e-posta, konu ve mesaj bilgilerini alarak Supabase veritabanına kaydeder.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/base_page.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  // Form kontrolü için gerekli key
  final _formKey = GlobalKey<FormState>();

  // Form alanları için text controller'lar
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();

  // Sayfa durumu için değişkenler
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _getUserEmail(); // Sayfa açıldığında kullanıcının e-posta adresini getir
  }

  @override
  void dispose() {
    // Controller'ları temizle
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Kullanıcının e-posta adresini Supabase veya SharedPreferences'dan getiren metod
  Future<void> _getUserEmail() async {
    try {
      // Önce Supabase'den oturum açmış kullanıcıyı kontrol et
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null && user.email != null) {
        setState(() {
          _emailController.text = user.email!;
        });
      } else {
        // Eğer Supabase'de kullanıcı yoksa Shared Preferences'ı dene
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('email');

        setState(() {
          if (email != null && email.isNotEmpty) {
            _emailController.text = email;
          } else {
            _emailController.text = "Email bilgisi bulunamadı";
          }
        });
      }
    } catch (e) {
      debugPrint("Email getirme hatası: $e");
      setState(() {
        _emailController.text = "Email bilgisi alınamadı";
      });
    }
  }

  // İletişim formunu Supabase'e gönderen metod
  Future<void> _submitContactForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isLoading = true;
          _statusMessage = '';
          _isSuccess = false;
        });

        final supabase = Supabase.instance.client;
        // Supabase'e veri ekleme
        await supabase.from('contact_messages').insert({
          'email': _emailController.text,
          'subject': _subjectController.text.trim(),
          'message': _messageController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
          'status': 'new', // Mesaj durumu (yeni, okundu, yanıtlandı vb.)
        });

        // Başarılı mesajı göster ve formu temizle
        setState(() {
          _statusMessage = 'Mesajınız başarıyla gönderildi. Teşekkür ederiz!';
          _isSuccess = true;
          _subjectController.clear();
          _messageController.clear();
        });
      } catch (e) {
        setState(() {
          _statusMessage = 'Bir hata oluştu: ${e.toString()}';
          _isSuccess = false;
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      title: 'Bize Ulaşın',
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sayfa başlığı ve açıklama metni
              const Text(
                'Sorularınız ve Önerileriniz İçin',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Size daha iyi hizmet verebilmemiz için düşüncelerinizi bizimle paylaşın.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // İletişim formu
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Kullanıcının e-posta adresi (salt okunur alan)
                    TextFormField(
                      readOnly: true,
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-posta Adresiniz',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Konu giriş alanı
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Konu',
                        prefixIcon: Icon(Icons.subject),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Lütfen bir konu girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Mesaj giriş alanı (çok satırlı)
                    TextFormField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Mesajınız',
                        prefixIcon: Icon(Icons.message),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Lütfen bir mesaj girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // İşlem durumu mesajı (başarılı/başarısız)
                    if (_statusMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              _isSuccess
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color:
                                _isSuccess
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Gönder butonu (yükleme durumunda spinner gösterir)
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitContactForm,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blue,
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'GÖNDER',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Sabit iletişim bilgileri kartı (e-posta, telefon, adres)
              const Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İletişim Bilgileri',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      ListTile(
                        leading: Icon(Icons.email_outlined),
                        title: Text('E-posta'),
                        subtitle: Text('030122023@std.izu.edu.tr'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      ListTile(
                        leading: Icon(Icons.phone_outlined),
                        title: Text('Telefon'),
                        subtitle: Text('+90 553 060 5053'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      ListTile(
                        leading: Icon(Icons.location_on_outlined),
                        title: Text('Adres'),
                        subtitle: Text(
                          'Halkalı Merkez, Halkalı, 34303 \nKüçükçekmece/İstanbul, Türkiye',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
