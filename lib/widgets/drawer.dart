import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DrawerMenu extends StatefulWidget {
  const DrawerMenu({super.key});

  @override
  State<DrawerMenu> createState() => _DrawerMenuState();
}

class _DrawerMenuState extends State<DrawerMenu> {
  String _userName = "Kullanıcı";
  String _userEmail = "kullanici@email.com";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  Future<void> _getUserInfo() async {
    try {
      // Supabase'den kullanıcı bilgilerini al
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        debugPrint("Kullanıcı bulundu, ID: ${user.id}, Email: ${user.email}");
        // Kullanıcı profil bilgilerini sorgula
        try {
          final userData =
              await supabase
                  .from('user_profiles')
                  .select()
                  .eq('id', user.id)
                  .maybeSingle();

          debugPrint("Profil bilgisi: $userData");

          setState(() {
            if (userData != null && userData['display_name'] != null) {
              _userName = userData['display_name'];
              debugPrint("display_name bulundu: ${userData['display_name']}");
            } else if (user.userMetadata != null &&
                user.userMetadata!['display_name'] != null) {
              _userName = user.userMetadata!['display_name'];
              debugPrint(
                "userMetadata'dan display_name: ${user.userMetadata!['display_name']}",
              );
            } else {
              debugPrint(
                "display_name bulunamadı, varsayılan değer kullanılıyor",
              );
            }

            _userEmail = user.email ?? _userEmail;
            _isLoading = false;
          });
        } catch (profileError) {
          debugPrint("Profil bilgisi sorgulama hatası: $profileError");
          setState(() {
            _userEmail = user.email ?? _userEmail;
            _isLoading = false;
          });
        }
      } else {
        // Eğer Supabase'de kullanıcı yoksa SharedPreferences'dan dene
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _userName = prefs.getString('name') ?? "Kullanıcı";
          _userEmail = prefs.getString('email') ?? _userEmail;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Kullanıcı bilgileri alınamadı: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigate(BuildContext context, String route) {
    Navigator.pop(context);
    if (ModalRoute.of(context)?.settings.name != route) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  Future<void> _logout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Çıkış'),
          content: const Text('Çıkmak istediğinize emin misiniz?'),
          actions: [
            TextButton(
              child: const Text('İptal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Evet'),
              onPressed: () async {
                // Dialog'u kapat
                Navigator.of(context).pop();

                try {
                  // Supabase'den çıkış yap
                  await Supabase.instance.client.auth.signOut();

                  // SharedPreferences'dan kullanıcı bilgilerini temizle
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('email');
                  await prefs.remove('name');

                  if (context.mounted) {
                    // Login sayfasına yönlendir
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Çıkış yapıldı')),
                    );
                  }
                } catch (e) {
                  debugPrint("Çıkış yapılırken hata: $e");
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Çıkış yapıldı, ancak bazı işlemler tamamlanamadı',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: <Widget>[
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            accountName: Text(_userName),
            accountEmail: Text(_userEmail),
            currentAccountPicture:
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const CircleAvatar(
                      backgroundImage: AssetImage('assets/avatar.png'),
                    ),
          ),
          ListTile(
            leading: const Icon(Icons.looks_one),
            title: const Text('Ana Sayfa'),
            onTap: () => _navigate(context, '/home'),
          ),
          ListTile(
            leading: const Icon(Icons.looks_two),
            title: const Text('Skorlarım'),
            onTap: () => _navigate(context, '/scores'),
          ),
          ListTile(
            leading: const Icon(Icons.looks_3),
            title: const Text('Bize Ulaşın'),
            onTap: () => _navigate(context, '/contact'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Ayarlar'),
            onTap: () => _navigate(context, '/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Çıkış'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
