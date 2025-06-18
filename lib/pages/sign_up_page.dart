import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        await _authService.signUpWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _displayNameController.text.trim(),
        ); // Başarılı kayıt mesajını göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kayıt işlemi başarıyla tamamlandı! Lütfen profil bilgilerinizi doldurun.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Profil tamamlama sayfasına yönlendir
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
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Google ile giriş yap
      final userCredential = await _authService.signInWithGoogle();

      // Kullanıcı popup'ı kapattıysa veya işlemi iptal ettiyse sessizce çık
      if (userCredential == null) {
        debugPrint('Google ile giriş yapılmadı veya işlem iptal edildi');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        // Başarılı kayıt mesajını göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google ile kayıt başarılı! Şimdi giriş yapabilirsiniz.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Login ekranına yönlendir
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      // Sadece gerçek hataları göster, iptal durumlarını değil
      if (e.toString().contains('sign_in_canceled') ||
          e.toString().contains('popup_closed') ||
          e.toString().contains('popup_blocked') ||
          e.toString().contains('canceled')) {
        debugPrint('Google ile kayıt işlemi iptal edildi: $e');
      } else {
        debugPrint('Google ile kayıt hatası: $e');
        setState(() {
          _errorMessage =
              'Google ile kayıt başarısız oldu. Lütfen tekrar deneyin.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGitHubSignUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _authService.signInWithGitHub(context);

      if (mounted) {
        // Başarılı kayıt mesajını göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'GitHub ile kayıt başarılı! Şimdi giriş yapabilirsiniz.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Login ekranına yönlendir
        Navigator.pushReplacementNamed(context, '/login');
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
      appBar: AppBar(
        title: const Text('Hesap Oluştur'),
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo
                const Icon(Icons.quiz, size: 80, color: Colors.blue),
                const SizedBox(height: 16),

                // Welcome text
                const Text(
                  'Bilgi Yarışmasına Kaydol',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hesabınızı oluşturun ve bilgi yarışmasına katılın',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Error message
                if (_errorMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Display Name
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Tam Adınız',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Lütfen adınızı girin';
                          }
                          if (value.trim().length < 2) {
                            return 'Adınız en az 2 karakter olmalıdır';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Adresi',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Lütfen email adresinizi girin';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Lütfen geçerli bir email adresi girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
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
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen şifrenizi girin';
                          }
                          if (value.length < 6) {
                            return 'Şifreniz en az 6 karakter olmalıdır';
                          }
                          if (!value.contains(RegExp(r'[A-Z]'))) {
                            return 'Şifreniz en az bir büyük harf içermelidir';
                          }
                          if (!value.contains(RegExp(r'[0-9]'))) {
                            return 'Şifreniz en az bir rakam içermelidir';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Şifreyi Onayla',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen şifrenizi onaylayın';
                          }
                          if (value != _passwordController.text) {
                            return 'Şifreler eşleşmiyor, lütfen tekrar deneyin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Sign Up button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignUp,
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
                                    'Hesap Oluştur',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Already have account
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Zaten hesabınız var mı?'),
                          TextButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : () => Navigator.pop(context),
                            child: const Text(
                              'Giriş Yap',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Divider
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

                const SizedBox(height: 24),

                // Social sign up buttons
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    icon: Image.network(
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
                    label: const Text(
                      'Google ile Kaydol',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleGoogleSignUp,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    icon: Image.network(
                      'https://qvoxksnfeirslohgtvfq.supabase.co/storage/v1/object/public/quizapp/logos/github-mark-white.png',
                      height: 24,
                      width: 24,
                      errorBuilder:
                          (context, error, stackTrace) => const Icon(
                            Icons.code,
                            size: 24,
                            color: Colors.black,
                          ),
                    ),
                    label: const Text(
                      'GitHub ile Kaydol',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Colors.black87,
                    ),
                    onPressed: _isLoading ? null : _handleGitHubSignUp,
                  ),
                ),

                const SizedBox(height: 24),

                // Terms and Privacy
                Text(
                  'Kayıt olarak, Hizmet Şartlarımızı ve Gizlilik Politikamızı kabul etmiş olursunuz.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
