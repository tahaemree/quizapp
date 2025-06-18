// ProfilePage, kullanıcının profil bilgilerini görüntüleyebildiği ve düzenleyebildiği sayfadır.
// Veriler öncelikle Firestore'dan, sonra SharedPreferences ve SQLite'tan yüklenir.
// Değişiklikler hem Firestore hem de Supabase'e kaydedilir.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../database/sqlite_service.dart';
import '../models/user_model.dart';
import '../widgets/base_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Form kontrolü ve veri girişi için controller'lar
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  // Veri servisleri
  late final AuthService _authService;
  final SQLiteService _sqliteService = SQLiteService();
  final SupabaseService _supabaseService = SupabaseService();

  // Sayfa durumu için değişkenler
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  UserModel? _userModel;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _loadUserProfile(); // Sayfa açıldığında kullanıcı profilini yükle
  }

  // Memory leak'leri önlemek için controller'ları temizle
  @override
  void dispose() {
    _displayNameController.dispose();
    _birthDateController.dispose();
    _birthPlaceController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // Kullanıcı profilini farklı kaynaklardan sırasıyla yüklemeye çalışan metod
  // 1. Firestore, 2. SharedPreferences, 3. SQLite sırası ile veri yüklenir
  Future<void> _loadUserProfile() async {
    try {
      // Öncelikle SharedPreferences'tan kullanıcı kimliğini al
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');

      if (uid != null) {
        debugPrint('UID BULUNDU: $uid, Firestore\'dan veri yükleniyor...');

        // En güncel verileri Firestore'dan almak için direkt Firestore'dan başlayalım
        try {
          final userDoc = await _authService.getUserFromFirestore(uid);
          debugPrint('Firestore userDoc alındı: ${userDoc != null}');
          debugPrint('Firestore belge var mı: ${userDoc?.exists}');

          if (userDoc != null && userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            debugPrint('Firestore userData içeriği: $userData');

            // Firestore alan isimlerini ayrıntılı olarak logla
            userData.forEach((key, value) {
              debugPrint('Firestore veri alanı: $key = $value');
            });

            final userModel = UserModel(
              uid: uid,
              email: userData['email'] ?? prefs.getString('email') ?? '',
              displayName: userData['display_name'] ?? '',
              birthDate: userData['birth_date'] ?? '',
              birthPlace: userData['birth_place'] ?? '',
              city: userData['city'] ?? '',
            );

            debugPrint(
              'Firestore\'dan oluşturulan userModel: ${userModel.toMap()}',
            );

            // UI'ı güncellemek için setState kullan ve daha önce çık
            if (mounted) {
              setState(() {
                _isLoading = false;
                _userModel = userModel;

                // Text controller'ları güncelle
                _displayNameController.text = userModel.displayName;
                _birthPlaceController.text = userModel.birthPlace;
                _cityController.text = userModel.city;

                // Tarih formatını kontrol et ve güncelle
                if (userModel.birthDate.isNotEmpty) {
                  _selectedDate = _parseDateString(userModel.birthDate);
                  // Tarih görüntüleme formatına çevir
                  _birthDateController.text = _formatDateForDisplay(
                    userModel.birthDate,
                  );
                } else {
                  _birthDateController.text = '';
                }
              });
            }

            // SharedPreferences'a güncel verileri kaydet
            await _authService.saveUserToPreferences(userModel);
            debugPrint('Firestore verileri SharedPreferences\'a kaydedildi');
            return;
          } else {
            debugPrint('Firestore belgesi bulunamadı veya boş');
          }
        } catch (e) {
          debugPrint('Firestore\'dan veri alınamadı: $e');
          // Firestore hatası durumunda diğer seçeneklere geç
        }

        debugPrint('SharedPreferences\'tan veri yükleniyor...');
        // SharedPreferences'tan veri almayı dene
        final userFromPrefs = await _authService.getUserFromPreferences();

        if (userFromPrefs != null && userFromPrefs.displayName.isNotEmpty) {
          debugPrint(
            'SharedPreferences\'tan veriler alındı: ${userFromPrefs.toMap()}',
          );

          if (mounted) {
            setState(() {
              _userModel = userFromPrefs;
              _displayNameController.text = userFromPrefs.displayName;
              _birthPlaceController.text = userFromPrefs.birthPlace;
              _cityController.text = userFromPrefs.city;

              // Tarih formatını kontrol et
              if (userFromPrefs.birthDate.isNotEmpty) {
                _selectedDate = _parseDateString(userFromPrefs.birthDate);
                // Tarih görüntüleme formatına çevir
                _birthDateController.text = _formatDateForDisplay(
                  userFromPrefs.birthDate,
                );
              } else {
                _birthDateController.text = '';
              }
            });
          }
          return;
        }

        debugPrint('SQLite\'tan veri yükleniyor...');
        // SharedPreferences'ta veri yoksa SQLite'tan almayı dene
        try {
          final userModel = await _sqliteService.getUser(uid);
          if (userModel != null) {
            debugPrint('SQLite\'tan veriler alındı: ${userModel.toMap()}');

            if (mounted) {
              setState(() {
                _userModel = userModel;
                _displayNameController.text = userModel.displayName;
                _birthPlaceController.text = userModel.birthPlace;
                _cityController.text = userModel.city;

                // Tarih formatını kontrol et
                if (userModel.birthDate.isNotEmpty) {
                  _selectedDate = _parseDateString(userModel.birthDate);
                  // Tarih görüntüleme formatına çevir
                  _birthDateController.text = _formatDateForDisplay(
                    userModel.birthDate,
                  );
                } else {
                  _birthDateController.text = '';
                }
              });
            }

            // SharedPreferences'a kaydet
            await _authService.saveUserToPreferences(userModel);
          }
        } catch (e) {
          debugPrint('SQLite\'tan veri alınamadı: $e');
        }
      }
    } catch (e) {
      _showErrorDialog('Profil yüklenirken hata oluştu: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Doğum tarihi seçimi için tarih seçici dialog'unu açan metod
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        // Formatlı tarihi kullan - DD/MM/YYYY
        _birthDateController.text = _formatDateForStorage(pickedDate);
      });
    }
  }

  // Profil bilgilerini güncelleyen metod
  // Firestore ve Supabase'e eş zamanlı kayıt yapar
  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        if (_userModel != null) {
          _userModel!.displayName = _displayNameController.text.trim();

          // Düzgün formatlı tarihi sakla - eğer _selectedDate varsa onu kullan
          if (_selectedDate != null) {
            _userModel!.birthDate = _formatDateForStorage(_selectedDate!);
          } else {
            // Tarih text controller'dan alınacaksa, formatını doğrula
            final dateText = _birthDateController.text.trim();
            if (dateText.isNotEmpty) {
              final parsedDate = _parseDateString(dateText);
              if (parsedDate != null) {
                _userModel!.birthDate = _formatDateForStorage(parsedDate);
              } else {
                _userModel!.birthDate = dateText;
              }
            } else {
              _userModel!.birthDate = '';
            }
          }

          _userModel!.birthPlace = _birthPlaceController.text.trim();
          _userModel!.city = _cityController.text.trim();
          debugPrint(
            'Profil güncelleniyor, kullanıcı verileri: ${_userModel!.toMap()}',
          );

          // Firebase/Firestore'a profil bilgilerini kaydet
          await _authService.updateUserProfile(_userModel!);

          // Supabase'e de profil bilgilerini kaydet
          try {
            await _supabaseService.saveUserProfile(_userModel!.toMap());
            debugPrint('Profil Supabase\'e başarıyla kaydedildi');
          } catch (e) {
            debugPrint('Supabase\'e profil kaydedilirken hata: $e');
            // Ana işlem Firestore olduğu için buradaki hatayı yok sayabiliriz
          }

          // Debug edilen kullanıcı verilerini yazdır
          _debugPrintUserData();

          setState(() {
            _isEditing = false;
          });

          // Profil bilgilerini yeniden yükle - güncel veriler için Firestore'a git
          await _loadUserProfile();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Profil başarıyla güncellendi'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } else {
          _showErrorDialog(
            'Kullanıcı profili bulunamadı. Lütfen tekrar giriş yapın.',
          );
        }
      } catch (e) {
        debugPrint('Profil güncelleme hatası: $e');
        _showErrorDialog('Profil güncellenirken hata oluştu: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  // Düzenleme modunu açıp kapatan metod
  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Eğer düzenleme iptal edilirse, orijinal değerleri geri yükle
        if (_userModel != null) {
          _displayNameController.text = _userModel!.displayName;
          _birthDateController.text = _userModel!.birthDate;
          _birthPlaceController.text = _userModel!.birthPlace;
          _cityController.text = _userModel!.city;
        }
      }
    });
  }

  // Kullanıcı çıkışını gerçekleştiren metod
  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      _showErrorDialog('Çıkış yapılırken hata oluştu: $e');
    }
  }

  // Hata mesajlarını gösteren dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hata'),
            content: Text(message),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          ),
    );
  }

  // Çıkış onayı için dialog
  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Çıkış Yap'),
            content: const Text(
              'Hesabınızdan çıkış yapmak istediğinizden emin misiniz?',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _signOut();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Çıkış Yap'),
              ),
            ],
          ),
    );
  }

  // Tarih formatı yardımcı metodları
  DateTime? _parseDateString(String dateString) {
    // Format kontrolü ve dönüşüm
    if (dateString.isEmpty) {
      return null;
    }

    try {
      // ISO format (YYYY-MM-DD) kontrolü
      if (dateString.contains('-')) {
        return DateTime.parse(dateString);
      }

      // DD/MM/YYYY format kontrolü
      if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[2]), // yıl
            int.parse(parts[1]), // ay
            int.parse(parts[0]), // gün
          );
        }
      }

      // Diğer format denemeleri
      return DateTime.tryParse(dateString);
    } catch (e) {
      debugPrint('Tarih dönüştürme hatası: $e');
      return null;
    }
  }

  String _formatDateForDisplay(String dateString) {
    final date = _parseDateString(dateString);
    if (date == null) return dateString;

    // DD/MM/YYYY formatına çevirme
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateForStorage(DateTime date) {
    // Firestore'da tercih edilen format
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Debug amaçlı kullanıcı bilgilerini yazdırma metodu
  void _debugPrintUserData() {
    if (_userModel != null) {
      debugPrint('===== KULLANICI BİLGİLERİ =====');
      debugPrint('UID: ${_userModel!.uid}');
      debugPrint('Email: ${_userModel!.email}');
      debugPrint('Display Name: ${_userModel!.displayName}');
      debugPrint('Birth Date: ${_userModel!.birthDate}');
      debugPrint('Birth Place: ${_userModel!.birthPlace}');
      debugPrint('City: ${_userModel!.city}');
      debugPrint('Text Controllers: ');
      debugPrint(' - Display Name: ${_displayNameController.text}');
      debugPrint(' - Birth Date: ${_birthDateController.text}');
      debugPrint(' - Birth Place: ${_birthPlaceController.text}');
      debugPrint(' - City: ${_cityController.text}');
      debugPrint('===============================');
    } else {
      debugPrint('UserModel null!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      title: 'Profil',
      content:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildProfileContent(),
    );
  }

  // Ana profil içeriğini oluşturan metod
  Widget _buildProfileContent() {
    if (_userModel == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Profil bilgileri yüklenemedi',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserProfile,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildProfileForm(),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  // Profil başlığını oluşturan metod (avatar ve kullanıcı bilgileri)
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blue.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    _userModel!.displayName.isNotEmpty
                        ? _userModel!.displayName[0].toUpperCase()
                        : _userModel!.email[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 20,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _userModel!.displayName.isNotEmpty
                ? _userModel!.displayName
                : 'Kullanıcı Adı Belirtilmemiş',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _userModel!.email,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Profil formunu oluşturan metod (kişisel bilgiler)
  Widget _buildProfileForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kişisel Bilgiler',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: _toggleEdit,
                  icon: Icon(
                    _isEditing ? Icons.close : Icons.edit,
                    color: _isEditing ? Colors.red : Colors.blue,
                  ),
                  tooltip:
                      _isEditing ? 'Düzenlemeyi İptal Et' : 'Profili Düzenle',
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildFormField(
              controller: _displayNameController,
              label: 'Ad Soyad',
              icon: Icons.person,
              enabled: _isEditing,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen ad soyad giriniz';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildFormField(
              controller: _birthPlaceController,
              label: 'Doğum Yeri',
              icon: Icons.location_on,
              enabled: _isEditing,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              controller: _cityController,
              label: 'Şehir',
              icon: Icons.location_city,
              enabled: _isEditing,
            ),
          ],
        ),
      ),
    );
  }

  // Form alanlarını oluşturan yardımcı metod
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: enabled ? Colors.blue : Colors.grey),
        filled: true,
        fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      validator: validator,
    );
  }

  // Tarih seçimi alanını oluşturan metod
  Widget _buildDateField() {
    return GestureDetector(
      onTap: _isEditing ? () => _selectDate(context) : null,
      child: AbsorbPointer(
        child: TextFormField(
          controller: _birthDateController,
          enabled: _isEditing,
          decoration: InputDecoration(
            labelText: 'Doğum Tarihi',
            prefixIcon: Icon(
              Icons.calendar_today,
              color: _isEditing ? Colors.blue : Colors.grey,
            ),
            suffixIcon:
                _isEditing
                    ? const Icon(Icons.arrow_drop_down, color: Colors.blue)
                    : null,
            filled: true,
            fillColor: _isEditing ? Colors.grey[50] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
      ),
    );
  }

  // Aksiyon butonlarını oluşturan metod (kaydet ve çıkış yap)
  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_isEditing) ...[
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isSaving
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Text(
                        'Değişiklikleri Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _showSignOutDialog,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text(
              'Çıkış Yap',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
