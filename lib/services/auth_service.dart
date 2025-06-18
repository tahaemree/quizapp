import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/sqlite_service.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart' as app_model;

/// Giriş yapma, kayıt olma ve profil yönetimi dahil
/// tüm kimlik doğrulama işlemlerini yöneten servis sınıfı.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseService _supabaseService = SupabaseService();
  final SQLiteService _sqliteService = SQLiteService();
  // Web platformu için belirli bir clientId kullanır, mobil için standart ayarları kullanır
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        kIsWeb
            ? '68569219915-0eq2tkc849jc653ggvmv3rgnkdhpvld0.apps.googleusercontent.com'
            : null,
  );
  AuthService() {
    debugPrint('AuthService Firebase Kimlik Doğrulama ile başlatıldı');
  } // Firestore'da kullanıcı dokümanı oluşturma/güncelleme yardımcı fonksiyonu
  Future<void> _createUserDocument(User user, {String? displayName}) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final userSnapshot = await userRef.get();

      // Kullanıcıyı tüm sistemlerde (Firestore, Supabase, SQLite) aynı bilgilerle oluşturacağız
      final userData = {
        'uid': user.uid,
        'email': user.email,
        'display_name':
            displayName ??
            user.displayName ??
            user.email?.split('@')[0] ??
            'User',
        'birth_date': '',
        'birth_place': '',
        'city': '',
        'created_at':
            DateTime.now()
                .toIso8601String(), // Firestore ve Supabase için uyumlu format
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 1. Firestore'a kaydet
      if (!userSnapshot.exists) {
        // Kullanıcı belgesi oluştur
        await userRef.set({
          ...userData,
          'created_at': FieldValue.serverTimestamp(), // Firestore özel format
          'last_login': FieldValue.serverTimestamp(),
        });
        debugPrint('Kullanıcı Firestore\'a kaydedildi: ${user.uid}');
      } else {
        // Sadece son giriş tarihini güncelle
        await userRef.update({
          'last_login': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        debugPrint('Kullanıcı Firestore\'da güncellendi: ${user.uid}');
      }

      // 2. Supabase'e kaydet - asenkron olarak ve hata durumunda işlemi durdurmadan devam et
      try {
        await _supabaseService.saveUserProfile(userData);
        debugPrint('Kullanıcı Supabase\'e kaydedildi: ${user.uid}');
      } catch (supabaseError) {
        debugPrint(
          'Supabase kullanıcı kaydı hatası, ancak işlem devam ediyor: $supabaseError',
        );
      }

      // 3. SQLite için kaydet (offline erişim için)
      await _saveUserToSQLite(userData);
    } catch (e) {
      debugPrint('Error creating/updating user document: $e');
      // Hatayı dışarıya bildir ki çağıran kod gerekirse ele alabilsin
      throw Exception(
        'Kullanıcı belgesi oluşturulurken/güncellenirken hata: $e',
      );
    }
  }

  // Helper for saving user data to SQLite and SharedPreferences (offline access)
  Future<void> _saveUserToSQLite(Map<String, dynamic> userData) async {
    try {
      final userModel = app_model.UserModel(
        uid: userData['uid'],
        email: userData['email'] ?? '',
        displayName: userData['display_name'] ?? '',
        birthDate: userData['birth_date'] ?? '',
        birthPlace: userData['birth_place'] ?? '',
        city: userData['city'] ?? '',
      );

      // SQLite'a kaydet (web dışı platformlar için)
      if (!kIsWeb) {
        await _sqliteService.saveUser(userModel);
        debugPrint('Kullanıcı SQLite\'a kaydedildi: ${userModel.uid}');
      }

      // SharedPreferences'a tüm kullanıcı bilgilerini kaydet
      await saveUserToPreferences(userModel);
      debugPrint('Kullanıcı SharedPreferences\'a kaydedildi: ${userModel.uid}');
    } catch (e) {
      debugPrint('Kullanıcı yerel veritabanına kaydedilirken hata: $e');
    }
  }

  // Email/Password Sign Up
  Future<UserCredential> signUpWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      debugPrint('Yeni kullanıcı kaydı başlatılıyor: $email');

      // 1. Firebase Authentication'a kaydol
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Kullanıcı profili güncelle
      await userCredential.user?.updateDisplayName(displayName);
      debugPrint(
        'Firebase Auth kullanıcı oluşturuldu: ${userCredential.user?.uid}',
      );

      // 2. Tüm sistemlere kaydet (Firestore, Supabase, SQLite)
      if (userCredential.user != null) {
        // Bu metod tüm sistemlere kayıt işlemini gerçekleştirecek
        await _createUserDocument(
          userCredential.user!,
          displayName: displayName,
        );
        debugPrint(
          'Kullanıcı tüm sistemlere kaydedildi: ${userCredential.user?.uid}',
        );
      }

      debugPrint('Yeni kullanıcı kaydı başarıyla tamamlandı: $email');

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase Auth Error during sign up: ${e.code} - ${e.message}',
      );
      throw _getAuthErrorMessage(e);
    } catch (e) {
      debugPrint('Error during sign up: $e');
      throw 'Kayıt işlemi başarısız: $e';
    }
  }

  // Email/Password Sign In
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Firestore ve SQLite'a kaydet/güncelle
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }

      debugPrint('Firebase sign in successful for: $email');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase Auth Error during sign in: ${e.code} - ${e.message}',
      );
      throw _getAuthErrorMessage(e);
    } catch (e) {
      debugPrint('Error during sign in: $e');
      throw 'Giriş başarısız: $e';
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // begin interactive sign in process
      final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();

      // user cancels google sign in pop up screen
      if (gUser == null) return null;
      // obtain auth details from request
      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      // Token yoksa sessizce çık
      if (gAuth.accessToken == null || gAuth.idToken == null) {
        debugPrint('Google kimlik doğrulama belirteçleri alınamadı');
        return null;
      }

      // create a new credential for user
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        try {
          debugPrint(
            'Google giriş başarılı, kullanıcı belgesi oluşturuluyor: [${userCredential.user?.uid}',
          );
          await _createUserDocument(userCredential.user!);
        } catch (docError) {
          debugPrint(
            'Google giriş sırasında belge oluşturma hatası: $docError',
          );
        }
      }
      return userCredential;
    } catch (e) {
      debugPrint('Google ile girişte hata: $e');
      return null;
    }
  }

  // GitHub Sign In
  Future<UserCredential?> signInWithGitHub(BuildContext context) async {
    try {
      // GitHub OAuth sağlayıcısını tanımla
      final provider = GithubAuthProvider();

      UserCredential? userCredential; // Nullable olarak tanımla

      if (kIsWeb) {
        // Web platformunda popup ile giriş
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        // Mobil platformlarda farklı yöntemlerle deneme
        try {
          userCredential = await _auth.signInWithProvider(provider);
        } catch (e) {
          // signInWithProvider hata verirse, signInWithRedirect deneyin
          await _auth.signInWithRedirect(provider);
          // Redirect sonrası sayfanın yeniden yüklenmesini bekleyin
          // userCredential'ı burada yeniden ata
          userCredential = await _auth.getRedirectResult();
          // return userCredential; // Bu return ifadesi burada olmamalı, en sonda olmalı
        }
      } // Firestore ve SQLite'a kaydet/güncelle
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);

        final userEmail = userCredential.user!.email ?? 'No email';
        debugPrint('GitHub sign in successful for: $userEmail');
      }
      return userCredential; // En sonda userCredential'ı döndür
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase Auth Error during GitHub sign in: ${e.code} - ${e.message}',
      );
      // Kullanıcı pencereyi kapattıysa sessizce null döndür
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return null;
      }
      throw _getAuthErrorMessage(e);
    } catch (e) {
      debugPrint('Error during GitHub sign in: $e');
      throw 'GitHub ile giriş başarısız: $e';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut(); // Google oturumunu kapat
      await _auth.signOut(); // Firebase oturumunu kapat

      // Local storage'ı temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('uid');
      await prefs.remove('email');

      debugPrint('Sign out successful');
    } catch (e) {
      debugPrint('Error signing out: $e');
      throw 'Çıkış yapılırken hata oluştu: $e';
    }
  }

  // Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    try {
      return _auth.currentUser != null;
    } catch (e) {
      debugPrint('Error checking login status: $e');
      return false;
    }
  }

  // Get current user profile
  Future<app_model.UserModel?> getCurrentUserProfile() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Firestore'dan kullanıcı belgesi al
        final docSnapshot =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (docSnapshot.exists && docSnapshot.data() != null) {
          final userData = docSnapshot.data() as Map<String, dynamic>;
          return app_model.UserModel(
            uid: userData['uid'] ?? currentUser.uid,
            email: userData['email'] ?? currentUser.email ?? '',
            displayName:
                userData['display_name'] ?? currentUser.displayName ?? '',
            birthDate: userData['birth_date'] ?? '',
            birthPlace: userData['birth_place'] ?? '',
            city: userData['city'] ?? '',
          );
        } // Firestore'da belge yoksa, Firebase Auth'dan al
        return app_model.UserModel(
          uid: currentUser.uid,
          email: currentUser.email ?? '',
          displayName: currentUser.displayName ?? '',
          birthDate: '',
          birthPlace: '',
          city: '',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(app_model.UserModel userModel) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Profil güncellemek için giriş yapmış olmalısınız';
      }

      debugPrint('Profil güncelleniyor, kullanıcı: ${currentUser.uid}');
      debugPrint('Güncellenecek veriler: ${userModel.toMap()}');

      // Kullanıcı adını güncelle (Firebase Auth)
      if (userModel.displayName.isNotEmpty &&
          userModel.displayName != currentUser.displayName) {
        await currentUser.updateDisplayName(userModel.displayName);
        debugPrint(
          'Firebase Auth displayName güncellendi: ${userModel.displayName}',
        );
      }

      final Map<String, dynamic> updateData = {
        'display_name': userModel.displayName,
        'birth_date': userModel.birthDate,
        'birth_place': userModel.birthPlace,
        'city': userModel.city,
        'updated_at': FieldValue.serverTimestamp(),
      };

      debugPrint('Firestore güncelleme verileri: $updateData');
      try {
        // Firestore belgesini güncelle
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .update(updateData);
        debugPrint('Firestore belgesi başarıyla güncellendi');
      } catch (firestoreError) {
        debugPrint('Firestore güncelleme hatası: $firestoreError');

        // Belge bulunamadı hatası alırsa, yeni belge oluştur
        if (firestoreError.toString().contains('not-found') ||
            firestoreError.toString().contains('No document to update')) {
          debugPrint(
            'Kullanıcı belgesi bulunamadı, yeni belge oluşturuluyor: ${currentUser.uid}',
          );

          final Map<String, dynamic> newDocData = {
            'uid': currentUser.uid,
            'email': currentUser.email,
            'display_name': userModel.displayName,
            'birth_date': userModel.birthDate,
            'birth_place': userModel.birthPlace,
            'city': userModel.city,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          };

          try {
            debugPrint('Yeni Firestore belgesi verileri: $newDocData');
            await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .set(newDocData);
            debugPrint('Yeni Firestore belgesi başarıyla oluşturuldu');

            // Bu bir hata değil, belge bulunamadığı için oluşturuldu ve işlem başarılı
            // Hata fırlatmadan devam et
          } catch (setError) {
            debugPrint('Firestore belge oluşturma hatası: $setError');
            // Gerçekten ciddi bir hata olduğunda hatayı fırlat
            throw 'Profil oluşturulurken bir hata oluştu: $setError';
          }
        } else {
          // Başka bir Firestore hatası olursa, yeniden fırlat
          debugPrint(
            'Bilinmeyen Firestore hatası: ${firestoreError.toString()}',
          );
          // Hata mesajını daha anlaşılır hale getir
          if (firestoreError.toString().contains('permission-denied')) {
            throw 'Yetki hatası: Profil güncellemek için gereken izinlere sahip değilsiniz.';
          } else {
            throw 'Profil güncellenirken bir hata oluştu. Lütfen tekrar deneyin.';
          }
        }
      } // SQLite'ı güncelle
      if (!kIsWeb) {
        await _sqliteService.saveUser(userModel);
        debugPrint('SQLite veritabanı güncellendi');
      }

      // Supabase'e kaydet
      try {
        await _supabaseService.saveUserProfile(userModel.toMap());
        debugPrint('Supabase profili güncellendi: ${userModel.uid}');
      } catch (supabaseError) {
        debugPrint(
          'Supabase güncellemede hata (işlem devam ediyor): $supabaseError',
        );
        // Hata olsa bile diğer sistemler çalışsın diye hatayı fırlatmıyoruz
      }

      // Kullanıcı bilgilerini SharedPreferences'a kaydet
      await saveUserToPreferences(userModel);
      debugPrint('SharedPreferences güncellendi');

      // Güncellemeden sonra doğrulama için belgeyi tekrar al
      final verifyDoc = await getUserFromFirestore(currentUser.uid);
      if (verifyDoc != null && verifyDoc.exists) {
        debugPrint('Güncelleme sonrası doğrulama: Belge mevcut');
        final data = verifyDoc.data();
        debugPrint('Güncellenen belge içeriği: $data');
      }

      debugPrint('Kullanıcı profili başarıyla güncellendi');
    } catch (e) {
      debugPrint('Profil güncelleme hatası: $e');
      throw 'Profil güncellenirken hata oluştu: $e';
    }
  }

  // Kullanıcının profil bilgilerinin tam olup olmadığını kontrol et
  Future<bool> isUserProfileComplete() async {
    try {
      final currentUser = _auth.currentUser;
      debugPrint(
        'isUserProfileComplete kontrol ediliyor, mevcut kullanıcı: ${currentUser?.uid}',
      );

      if (currentUser == null) {
        debugPrint('Mevcut kullanıcı boş, profil tamamlanmamış');
        return false;
      }

      // Önce Firestore'dan belge kontrolü yap
      try {
        final docSnapshot =
            await _firestore.collection('users').doc(currentUser.uid).get();
        debugPrint('Firestore belgesi mevcut mu? ${docSnapshot.exists}');

        if (docSnapshot.exists && docSnapshot.data() != null) {
          final userData = docSnapshot.data() as Map<String, dynamic>;

          final birthDate = userData['birth_date'] as String? ?? '';
          final birthPlace = userData['birth_place'] as String? ?? '';
          final city = userData['city'] as String? ?? '';

          debugPrint(
            'birthDate: "$birthDate", birthPlace: "$birthPlace", city: "$city"',
          );

          // Tüm alanlar dolu mu?
          return birthDate.isNotEmpty &&
              birthPlace.isNotEmpty &&
              city.isNotEmpty;
        } else {
          debugPrint(
            'Kullanıcı belgesi Firestore\'da bulunamadı, profil tamamlanmamış',
          );
          return false;
        }
      } catch (firestoreError) {
        debugPrint('Firestore belgesi kontrol edilirken hata: $firestoreError');

        // Alternatif olarak yerel profil kontrolü dene
        final userProfile = await getCurrentUserProfile();
        if (userProfile == null) {
          debugPrint('Profil bilgileri alınamadı');
          return false;
        }

        debugPrint(
          'Alternatif kontrol - birthDate: "${userProfile.birthDate}", birthPlace: "${userProfile.birthPlace}", city: "${userProfile.city}"',
        );
        return userProfile.birthDate.isNotEmpty &&
            userProfile.birthPlace.isNotEmpty &&
            userProfile.city.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Profil kontrolü sırasında genel hata: $e');
      return false;
    }
  }

  // Firebase Auth hata kodlarını kullanıcı dostu mesajlara dönüştür
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi formatı.';
      case 'weak-password':
        return 'Şifre çok zayıf. Lütfen daha güçlü bir şifre seçin.';
      case 'user-not-found':
        return 'Bu e-posta adresine kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'E-posta adresi veya şifre hatalı.';
      case 'account-exists-with-different-credential':
        return 'Bu e-posta adresi başka bir giriş yöntemiyle kayıtlı.';
      case 'invalid-credential':
        return 'Giriş bilgileri geçersiz. Lütfen tekrar deneyin.';
      case 'user-disabled':
        return 'Bu kullanıcı hesabı devre dışı bırakılmış.';
      case 'operation-not-allowed':
        return 'Bu giriş yöntemi şu anda etkin değil.';
      case 'too-many-requests':
        return 'Çok fazla başarısız giriş denemesi. Lütfen daha sonra tekrar deneyin.';
      default:
        return e.message ?? 'Beklenmeyen bir hata oluştu.';
    }
  }

  // Save all user profile data to SharedPreferences
  Future<void> saveUserToPreferences(app_model.UserModel userModel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', userModel.uid);
    await prefs.setString('email', userModel.email);
    await prefs.setString('display_name', userModel.displayName);
    await prefs.setString('birth_date', userModel.birthDate);
    await prefs.setString('birth_place', userModel.birthPlace);
    await prefs.setString('city', userModel.city);

    debugPrint(
      'Tüm kullanıcı bilgileri SharedPreferences\'a kaydedildi: ${userModel.uid}',
    );
  }

  // Get user profile data from SharedPreferences
  Future<app_model.UserModel?> getUserFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');

    if (uid == null) return null;

    return app_model.UserModel(
      uid: uid,
      email: prefs.getString('email') ?? '',
      displayName: prefs.getString('display_name') ?? '',
      birthDate: prefs.getString('birth_date') ?? '',
      birthPlace: prefs.getString('birth_place') ?? '',
      city: prefs.getString('city') ?? '',
    );
  }

  // Firestore'dan kullanıcı belgesini al
  Future<DocumentSnapshot?> getUserFromFirestore(String uid) async {
    try {
      debugPrint('Firestore belge isteminde bulunuluyor, uid: $uid');
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final data = userDoc.data();
        debugPrint('Firestore belge içeriği: ${data ?? 'NULL'}');

        if (data != null) {
          debugPrint('Firestore alan isimleri:');
          data.forEach((key, value) {
            debugPrint('  $key: $value');
          });
        }
      } else {
        debugPrint('Firestore belgesi bulunamadı (exists=false)');
      }

      return userDoc;
    } catch (e) {
      debugPrint('Firestore\'dan kullanıcı verileri alınamadı: $e');
      return null;
    }
  }
}
