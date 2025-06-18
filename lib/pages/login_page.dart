// LoginPage, kullanıcıların uygulamaya giriş yapabilecekleri sayfadır.
// E-posta/şifre, Google veya GitHub ile giriş seçenekleri sunar.
// Giriş sonrası kullanıcının profil durumuna göre yönlendirme yapar.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb için
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Form kontrolü ve veri girişi için controller'lar
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Servis ve durum değişkenleri
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;

  @override
  void dispose() {
    // Controller'ları temizle
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // E-posta/şifre ile giriş işlemini yöneten metod
  Future<void> _handleSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        await _authService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        // Kullanıcının profil bilgilerinin tam olup olmadığını kontrol et
        bool isProfileComplete = await _authService.isUserProfileComplete();

        if (mounted) {
          if (isProfileComplete) {
            // Profil bilgileri tam ise ana sayfaya yönlendir
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            // Profil bilgileri eksikse profil tamamlama sayfasına yönlendir
            Navigator.pushReplacementNamed(context, '/complete_profile');
          }
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Google ile giriş işlemini yöneten metod
  // Web ve mobil platformlar için farklı işlemler içerir
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      debugPrint('Google ile giriş başlatılıyor...');

      // Google ile giriş yap
      final userCredential = await _authService.signInWithGoogle();

      // Debug için
      debugPrint(
        'Google giriş sonucu: ${userCredential != null ? "Başarılı" : "İptal edildi"}',
      );

      // Kullanıcı popup'ı kapattıysa veya giriş yapmadıysa sessizce çık
      if (userCredential == null) {
        debugPrint('Google ile giriş yapılmadı veya işlem iptal edildi');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Debug için kullanıcı bilgilerini yazdır
      debugPrint('Kullanıcı UID: ${userCredential.user?.uid}');
      debugPrint('Kullanıcı Email: ${userCredential.user?.email}');

      if (mounted) {
        try {
          debugPrint(
            'Profil bilgilerinin tamamlanmışlığı kontrol ediliyor...',
          ); // Kullanıcının profil bilgilerinin tam olup olmadığını kontrol et
          bool isProfileComplete = await _authService.isUserProfileComplete();
          debugPrint('Profil tamamlanmış mı? $isProfileComplete');

          if (!mounted) return;

          if (isProfileComplete) {
            // Profil bilgileri tam ise ana sayfaya yönlendir
            debugPrint('Profil tam, ana sayfaya yönlendiriliyor...');
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            // Profil bilgileri eksikse profil tamamlama sayfasına yönlendir
            debugPrint(
              'Profil eksik, profil tamamlama sayfasına yönlendiriliyor...',
            );
            Navigator.pushReplacementNamed(context, '/complete_profile');
          }
        } catch (profileCheckError) {
          debugPrint('Profil kontrolü sırasında hata: $profileCheckError');
          // Hata durumunda ana sayfaya yönlendir
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      // Sadece gerçek hataları göster, iptal durumlarını değil
      if (e.toString().contains('sign_in_canceled') ||
          e.toString().contains('popup_closed') ||
          e.toString().contains('popup_blocked') ||
          e.toString().contains('canceled')) {
        debugPrint('Google ile giriş işlemi iptal edildi: $e');
      } else {
        debugPrint('Google ile giriş hatası: $e');
        if (mounted) {
          setState(() {
            _errorMessage =
                'Google ile giriş başarısız oldu. Lütfen tekrar deneyin.';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // GitHub ile giriş işlemini yöneten metod
  Future<void> _handleGitHubSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _authService.signInWithGitHub(
        context,
      ); // Kullanıcının profil bilgilerinin tam olup olmadığını kontrol et
      bool isProfileComplete = await _authService.isUserProfileComplete();

      if (!mounted) return;

      if (isProfileComplete) {
        // Profil bilgileri tam ise ana sayfaya yönlendir
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Profil bilgileri eksikse profil tamamlama sayfasına yönlendir
        Navigator.pushReplacementNamed(context, '/complete_profile');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Uygulama logosu ve başlık metinleri
                const Icon(Icons.quiz, size: 80, color: Colors.blue),
                const SizedBox(height: 16), // Uygulama adı
                const Text(
                  'Tekrar Hoşgeldiniz',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bilgi Yarışması hesabınıza giriş yapın',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Hata mesajı gösterimi (varsa)
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                const SizedBox(height: 16),

                // Giriş formu
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // E-posta giriş alanı
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-posta Adresi',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Lütfen e-posta adresinizi girin';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Lütfen geçerli bir e-posta adresi girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Şifre giriş alanı (göster/gizle özellikli)
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen şifrenizi girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Giriş yap butonu (yükleme durumunda spinner gösterir)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text(
                                    'Giriş Yap',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),
                      // Kayıt sayfasına yönlendirme linki
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Hesabın yok mu? '),
                          TextButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : () {
                                      Navigator.pushNamed(context, '/signup');
                                    },
                            child: const Text(
                              'Kaydol',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Alternatif giriş yöntemleri ayırıcı
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'VEYA',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 24), // Sosyal login buttons
                // Web platformunda özel Google giriş butonu
                if (kIsWeb)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed:
                          _isLoading
                              ? null
                              : () async {
                                setState(() {
                                  _isLoading = true;
                                  _errorMessage = '';
                                });
                                final userCredential =
                                    await _authService.signInWithGoogle();
                                if (userCredential == null) {
                                  setState(() {
                                    _isLoading = false;
                                    _errorMessage =
                                        'Google ile giriş başarısız veya iptal edildi.';
                                  });
                                  return;
                                }
                                // Profil kontrolü ve yönlendirme
                                try {
                                  bool isProfileComplete =
                                      await _authService
                                          .isUserProfileComplete();
                                  // mounted kontrolü Navigator çağrılarından HEMEN ÖNCE olmalı
                                  if (isProfileComplete) {
                                    if (!mounted) return;
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/home',
                                    );
                                  } else {
                                    if (!mounted) return;
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/complete_profile',
                                    );
                                  }
                                } catch (e) {
                                  // mounted kontrolü Navigator çağrılarından HEMEN ÖNCE olmalı
                                  if (!mounted) return;
                                  Navigator.pushReplacementNamed(
                                    context,
                                    '/home',
                                  );
                                }
                                setState(() {
                                  _isLoading = false;
                                });
                              },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://qvoxksnfeirslohgtvfq.supabase.co/storage/v1/object/public/quizapp/logos/google_logo.jpg',
                            height: 24,
                            width: 24,
                            errorBuilder:
                                (context, error, stackTrace) => const Icon(
                                  Icons.g_mobiledata,
                                  size: 24,
                                  color: Colors.red,
                                ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Google ile giriş yap',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://qvoxksnfeirslohgtvfq.supabase.co/storage/v1/object/public/quizapp/logos/google_logo.jpg',
                            height: 24,
                            width: 24,
                            errorBuilder:
                                (context, error, stackTrace) => const Icon(
                                  Icons.g_mobiledata,
                                  size: 24,
                                  color: Colors.red,
                                ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Google ile Giriş Yap',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleGitHubSignIn,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Colors.black87,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://qvoxksnfeirslohgtvfq.supabase.co/storage/v1/object/public/quizapp/logos/github-mark-white.png',
                          height: 24,
                          width: 24,
                          errorBuilder:
                              (context, error, stackTrace) => const Icon(
                                Icons.code,
                                size: 24,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'GitHub ile Giriş Yap',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
