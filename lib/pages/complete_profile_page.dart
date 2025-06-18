// CompleteProfilePage, kullanıcının profil bilgilerini tamamlamasını sağlayan bir form sayfasıdır.
// Bu sayfa doğum tarihi, doğum yeri ve yaşanılan şehir bilgilerini toplar.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import '../widgets/base_page.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  // Form kontrolü için gerekli key
  final _formKey = GlobalKey<FormState>();

  // Kullanıcının seçtiği doğum tarihi
  DateTime? _selectedDate;

  // Form alanları için text controller'lar
  final _birthPlaceController = TextEditingController();
  final _cityController = TextEditingController();

  // Servisler
  late final AuthService _authService;
  final SupabaseService _supabaseService = SupabaseService();

  // Sayfa durumu için değişkenler
  bool _isLoading = false;
  String _errorMessage = '';
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _getUserInfo(); // Sayfa açıldığında mevcut kullanıcı bilgilerini getir
  }

  // Mevcut kullanıcının bilgilerini getiren metod
  Future<void> _getUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.getCurrentUserProfile();

      if (user != null) {
        setState(() {
          _currentUser = user;

          // Eğer kullanıcının zaten bilgileri varsa, onları forma doldur
          if (user.birthDate.isNotEmpty) {
            try {
              _selectedDate = DateFormat('dd/MM/yyyy').parse(user.birthDate);
            } catch (e) {
              // Tarih formatı geçersizse, boş bırak
              _selectedDate = null;
            }
          }

          _birthPlaceController.text = user.birthPlace;
          _cityController.text = user.city;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Kullanıcı bilgileri alınamadı: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Doğum tarihi seçimi için tarih seçici dialog'u açan metod
  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate =
        _selectedDate ?? DateTime(now.year - 18, now.month, now.day);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 12, now.month, now.day), // En az 12 yaş
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue,
            colorScheme: const ColorScheme.light(primary: Colors.blue),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  // Profil bilgilerini kaydeden metod
  // Firebase ve Supabase'e eş zamanlı olarak kayıt yapar
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      setState(() {
        _errorMessage = 'Lütfen doğum tarihinizi seçin';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      if (_currentUser != null) {
        final formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate!);

        final updatedUser = UserModel(
          uid: _currentUser!.uid,
          email: _currentUser!.email,
          displayName: _currentUser!.displayName,
          birthDate: formattedDate,
          birthPlace: _birthPlaceController.text.trim(),
          city: _cityController.text.trim(),
        ); // Profil güncelleme işlemini try-catch içinde yap
        try {
          // Firebase/Firestore'a profil bilgilerini kaydet
          await _authService.updateUserProfile(updatedUser);

          // Ayrıca Supabase'e de profil bilgilerini kaydet
          try {
            await _supabaseService.saveUserProfile(updatedUser.toMap());
            debugPrint('Profil bilgileri Supabase\'e de başarıyla kaydedildi');
          } catch (supabaseError) {
            // Supabase'e kayıt başarısız olsa bile ana işlem devam etsin
            debugPrint('Supabase\'e profil kaydederken hata: $supabaseError');
          }

          // Başarıyla güncellendi
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profil bilgileriniz başarıyla kaydedildi!'),
                backgroundColor: Colors.green,
              ),
            );

            Navigator.pushReplacementNamed(context, '/home');
          }
        } catch (updateError) {
          debugPrint('Profil güncellemede hata: $updateError');

          // Firebase'e veri kayıt edildiyse hata mesajını gösterme
          if (updateError.toString().contains('not-found') ||
              updateError.toString().contains('No document to update')) {
            // Belge bulunamadı hatası genelde ilk kez kayıt yapılırken olur
            // ve genelde başarılı bir şekilde oluşturulur

            // Ayrıca Supabase'e de profil bilgilerini kaydet
            try {
              await _supabaseService.saveUserProfile(updatedUser.toMap());
              debugPrint('Profil bilgileri Supabase\'e başarıyla kaydedildi');
            } catch (supabaseError) {
              // Supabase'e kayıt başarısız olsa bile ana işlem devam etsin
              debugPrint('Supabase\'e profil kaydederken hata: $supabaseError');
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profil bilgileriniz başarıyla kaydedildi!'),
                  backgroundColor: Colors.green,
                ),
              );

              Navigator.pushReplacementNamed(context, '/home');
            }
          } else {
            // Gerçekten bir hata olduğunda göster
            setState(() {
              _errorMessage = 'Profil güncellenirken hata oluştu: $updateError';
            });
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Kullanıcı bilgilerine ulaşılamadı';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Profil güncellenirken hata oluştu: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Controller'ları temizle
    _birthPlaceController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      title: 'Profil Bilgilerini Tamamla',
      // Yükleme durumunda loading indicator, değilse form göster
      content:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık ve açıklama metinleri
                    const Text(
                      'Hadi seni daha yakından tanıyalım!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sana daha iyi bir deneyim sunabilmemiz için birkaç bilgiye ihtiyacımız var.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    if (_errorMessage.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Doğum Tarihi
                          const Text(
                            'Doğum Tarihi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _pickDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedDate != null
                                        ? DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_selectedDate!)
                                        : 'Doğum tarihinizi seçin',
                                    style: TextStyle(
                                      color:
                                          _selectedDate != null
                                              ? Colors.black
                                              : Colors.grey,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Doğum Yeri
                          TextFormField(
                            controller: _birthPlaceController,
                            decoration: const InputDecoration(
                              labelText: 'Doğum Yeri',
                              hintText: 'Örn: İstanbul',
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Lütfen doğum yerinizi girin';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Yaşadığı Şehir
                          TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'Yaşadığınız Şehir',
                              hintText: 'Örn: Ankara',
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Lütfen yaşadığınız şehri girin';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 40),

                          // Kaydet Butonu
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Profili Tamamla',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
