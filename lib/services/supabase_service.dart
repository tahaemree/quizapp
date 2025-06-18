import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/quiz_model.dart';
import '../database/sqlite_service.dart';

class SupabaseService {
  late final SupabaseClient _supabaseClient;

  // Constructor with error handling for Supabase client
  SupabaseService() {
    try {
      _supabaseClient = Supabase.instance.client;
      debugPrint('Supabase client successfully initialized');
      // Uygulama başlarken tablo yapısını kontrol et
      _initializeSupabase();
    } catch (e) {
      debugPrint('Error initializing Supabase client: $e');
      // We'll still let the class initialize, and handle errors in the methods
    }
  }
  // Initialize Supabase tables and structures
  Future<void> _initializeSupabase() async {
    try {
      debugPrint('Supabase veri yapıları kontrol ediliyor...');

      // Scores tablosunun varlığını kontrol et
      bool scoresTableExists = await _checkIfTableExists('scores');

      if (!scoresTableExists) {
        debugPrint('Scores tablosu bulunamadı, oluşturuluyor...');
        // SQL sorgusuyla tabloyu oluştur
        final createTableSQL = '''
        CREATE TABLE IF NOT EXISTS scores (
          id BIGSERIAL PRIMARY KEY,
          user_id TEXT NOT NULL,
          score INTEGER NOT NULL,
          date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          category_id TEXT DEFAULT 'general',
          category_name TEXT DEFAULT 'Genel',
          total_questions INTEGER DEFAULT 10,
          score_percent INTEGER DEFAULT 0
        );
        
        -- İndex ekleyelim, sorgular daha hızlı olsun
        CREATE INDEX IF NOT EXISTS idx_scores_user_id ON scores(user_id);
        CREATE INDEX IF NOT EXISTS idx_scores_category_id ON scores(category_id);
        
        -- RLS (Row Level Security) politikaları
        ALTER TABLE scores ENABLE ROW LEVEL SECURITY;
        
        -- Herkes kendi skorlarını görsün, yöneticiler hepsini görsün
        CREATE POLICY "Kullanıcılar kendi skorlarını görebilir" 
          ON scores FOR SELECT 
          USING (auth.uid()::text = user_id OR auth.uid() IN (
            SELECT uid FROM user_profiles WHERE role = 'admin'
          ));
          
        -- Herkes kendi skorlarını oluşturabilir
        CREATE POLICY "Kullanıcılar kendi skorlarını oluşturabilir" 
          ON scores FOR INSERT 
          WITH CHECK (auth.uid()::text = user_id);
          
        -- Herkes kendi skorlarını güncelleyebilir
        CREATE POLICY "Kullanıcılar kendi skorlarını güncelleyebilir" 
          ON scores FOR UPDATE 
          USING (auth.uid()::text = user_id);
        ''';

        try {
          // SQL sorgusu çalıştır
          await _supabaseClient.rpc(
            'run_sql',
            params: {'query': createTableSQL},
          );
          debugPrint(
            'Scores tablosu başarıyla oluşturuldu ve güvenlik politikaları ayarlandı',
          );

          // Başarılı bir şekilde oluşturduktan sonra varlığını bir kez daha doğrula
          bool tableCreated = await _checkIfTableExists('scores');
          if (tableCreated) {
            debugPrint('Tablo başarılı şekilde oluşturulduğu doğrulandı');
          } else {
            debugPrint(
              'UYARI: Tablo oluşturma başarılı gibi görünse de, tablo bulunamadı',
            );
          }
        } catch (sqlError) {
          debugPrint('SQL çalıştırma hatası: $sqlError');
          // SQL hata ayrıntısını analiz edelim
          if (sqlError.toString().contains('permission denied') ||
              sqlError.toString().contains('rpc')) {
            debugPrint(
              'SQL yetki hatası: RPC "run_sql" işlevi mevcut değil veya yetkisiz',
            );
            // Alternatif yöntem: Scores tablosunu direkt insert ile oluşturmayı dene
            await _createScoresTableAlternative();
          }
        }
      } else {
        debugPrint('Scores tablosu zaten mevcut, kontrol tamamlandı');
      }
    } catch (e) {
      debugPrint('Supabase yapıları kontrol edilirken hata: $e');
      // Buradaki hatalar kritik değil, uygulamanın devam etmesine izin ver
    }
  }

  // Check if a table exists in Supabase
  Future<bool> _checkIfTableExists(String tableName) async {
    try {
      // Bu tablo üzerinde basit bir sorgu çalıştır
      await _supabaseClient.from(tableName).select('id').limit(1);
      return true; // Hata olmadıysa tablo var demektir
    } catch (e) {
      debugPrint('Tablo kontrol hatası ($tableName): $e');
      return false; // Hata varsa tablo yok veya erişilemiyor demektir
    }
  }

  // Tüm sorular - Sadece Supabase'den veri çeken versiyon
  Future<List<QuestionModel>> fetchRandomQuestions(int limit) async {
    try {
      final response = await _supabaseClient
          .from('questions')
          .select()
          .order('id', ascending: false)
          .limit(limit);

      final questions =
          (response as List)
              .map((question) => QuestionModel.fromMap(question))
              .toList();

      if (questions.isEmpty) {
        throw Exception('Veritabanında hiç soru bulunamadı');
      }

      return questions;
    } catch (e) {
      debugPrint('Error fetching questions from Supabase: $e');
      throw Exception('Sorular yüklenirken bir hata oluştu: $e');
    }
  }

  // Kategori bazlı sorular - Sadece Supabase'den veri çeken versiyon
  Future<List<QuestionModel>> fetchQuestionsByCategory(
    String categoryId,
    int limit,
  ) async {
    try {
      final response = await _supabaseClient
          .from('questions')
          .select()
          .eq('category', categoryId)
          .order('id', ascending: false)
          .limit(limit);

      final questions =
          (response as List)
              .map((question) => QuestionModel.fromMap(question))
              .toList();

      if (questions.isEmpty) {
        // Kategoride hiç soru yoksa hata fırlat
        throw Exception('Bu kategoride hiç soru bulunamadı.');
      }

      return questions;
    } catch (e) {
      debugPrint('Error fetching category questions from Supabase: $e');
      throw Exception('Kategori soruları yüklenirken bir hata oluştu: $e');
    }
  } // Test connection to Supabase

  Future<bool> testConnection() async {
    try {
      await _supabaseClient.from('questions').select().limit(1);
      debugPrint('Supabase connection successful');
      return true;
    } catch (e) {
      debugPrint('Supabase connection test failed: $e');
      return false;
    }
  } // Score API operations

  Future<void> saveScore(
    String userId,
    int score, {
    String? categoryId,
    String? categoryName,
    int totalQuestions = 10,
    int? scorePercent,
  }) async {
    try {
      debugPrint('Skor kaydetme işlemi başlatıldı (Supabase & SQLite)...');
      debugPrint('Kullanıcı ID: $userId, Skor: $score/$totalQuestions');

      // Verileri hazırla
      final scoreData = {
        'user_id': userId,
        'score': score,
        'date': DateTime.now().toIso8601String(),
        'category_id': categoryId ?? 'general',
        'category_name': categoryName ?? 'Genel',
        'total_questions': totalQuestions,
        'score_percent':
            scorePercent ?? ((score / totalQuestions) * 100).round(),
      };

      // SQLite'a da kaydet (web dışı platformlar için)
      if (!kIsWeb) {
        try {
          // UserScore nesnesi oluştur
          final userScore = UserScore(
            userId: userId,
            score: score,
            date: DateTime.now(),
            categoryId: categoryId ?? 'general',
            categoryName: categoryName ?? 'Genel',
            totalQuestions: totalQuestions,
            scorePercent:
                scorePercent ?? ((score / totalQuestions) * 100).round(),
          );

          // SQLite'a kaydet
          final sqliteService = SQLiteService();
          await sqliteService.saveScore(userScore);
          debugPrint('Skor SQLite\'a başarıyla kaydedildi: $score puan');
        } catch (sqliteError) {
          debugPrint('SQLite\'a skor kaydetme hatası: $sqliteError');
          // Hatayı yut, Supabase kaydına devam et
        }
      }

      debugPrint('Supabase\'e gönderilecek skor verileri: $scoreData');

      // Önce scores tablosunun varlığını kontrol et
      bool tableExists = await _checkIfTableExists('scores');
      if (!tableExists) {
        debugPrint('Scores tablosu mevcut değil, oluşturuluyor...');
        try {
          await _createScoresTable();
          debugPrint(
            'Scores tablosu başarıyla oluşturuldu. Skor kaydedilecek.',
          );
        } catch (tableError) {
          debugPrint(
            'Tablo oluşturma başarısız, alternatif yöntem deneniyor: $tableError',
          );
          try {
            await _createScoresTableAlternative();
          } catch (alternativeError) {
            debugPrint(
              'Alternatif tablo oluşturma da başarısız: $alternativeError',
            );
            // Alternatif de başarısızsa, sadece insert ile devam et, belki tablo vardır
          }
        }
      }

      // Veriyi ekle - try-catch ile çevreleyerek daha spesifik hata mesajları al
      try {
        // upsert yerine doğrudan insert kullanarak kaydet
        final response =
            await _supabaseClient.from('scores').insert(scoreData).select();

        debugPrint('Supabase yanıtı: $response');
        debugPrint(
          'Skor başarıyla kaydedildi: $score puan, ${scoreData['category_name']}',
        );
        return;
      } catch (insertError) {
        debugPrint('Insert hatası, upsert deneniyor: $insertError');

        // Insert başarısız olduysa upsert dene
        try {
          final response = await _supabaseClient
              .from('scores')
              .upsert(scoreData);

          debugPrint('Upsert başarılı: $response');
          return;
        } catch (upsertError) {
          debugPrint('Upsert hatası: $upsertError');

          // Tüm insert/upsert denemeleri başarısızsa ve tablo yok hatası alınıyorsa
          if (insertError.toString().contains('does not exist') ||
              upsertError.toString().contains('does not exist')) {
            // Son çare: Alternatif tablo oluşturma ve direk insert
            try {
              debugPrint(
                'Son çare: Alternatif metod ile tabloyu yeniden oluşturma...',
              );
              await _createScoresTableAlternative();

              // Bir kez daha insert dene
              await _supabaseClient.from('scores').insert(scoreData);
              debugPrint('Tablo oluşturuldu ve skor başarıyla kaydedildi!');
              return;
            } catch (lastError) {
              debugPrint('Son çare denemesi başarısız: $lastError');
              throw Exception('Skor kaydedilemedi: $lastError');
            }
          } else {
            // Başka bir hata
            throw Exception('Skor eklenirken hata: $upsertError');
          }
        }
      } // SQLite kısmı yukarıda işlendi, bu kod artık gerekli değil
    } catch (e) {
      // Tüm hatalar için genel yakalama
      debugPrint('Skor kaydedilirken genel hata: $e');
      rethrow; // Hatayı yeniden fırlat ki üst katman işleyebilsin
    }
  }

  // Scores tablosunu oluştur
  Future<void> _createScoresTable() async {
    try {
      // SQL sorgusuyla tabloyu oluştur
      final createTableSQL = '''
      CREATE TABLE IF NOT EXISTS scores (
        id BIGSERIAL PRIMARY KEY,
        user_id TEXT NOT NULL,
        score INTEGER NOT NULL,
        date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        category_id TEXT DEFAULT 'general',
        category_name TEXT DEFAULT 'Genel',
        total_questions INTEGER DEFAULT 10,
        score_percent INTEGER DEFAULT 0
      );
      ''';

      // SQL sorgusu çalıştır
      await _supabaseClient.rpc('run_sql', params: {'query': createTableSQL});
      debugPrint('Scores tablosu başarıyla oluşturuldu');
    } catch (e) {
      debugPrint('Tablo oluşturma hatası: $e');
      throw Exception('Scores tablosu oluşturulamadı: $e');
    }
  }

  // Scores tablosunu alternatif yöntemle oluştur - SQL RPC olmadan
  Future<void> _createScoresTableAlternative() async {
    try {
      debugPrint(
        'Scores tablosunu alternatif yöntem ile oluşturmaya çalışılıyor...',
      );

      // Basit bir kayıt ekleyerek tablo oluşturmayı dene
      final testScore = {
        'user_id': 'test_user',
        'score': 0,
        'date': DateTime.now().toIso8601String(),
        'category_id': 'test',
        'category_name': 'Test',
        'total_questions': 1,
        'score_percent': 0,
      };

      // Test kaydı ekle - tablo yoksa otomatik oluşacak
      await _supabaseClient.from('scores').insert(testScore);

      // Test kaydını sil
      await _supabaseClient
          .from('scores')
          .delete()
          .eq('user_id', 'test_user')
          .eq('category_id', 'test');

      debugPrint('Scores tablosu alternatif yöntem ile oluşturuldu');
    } catch (e) {
      debugPrint('Alternatif tablo oluşturma hatası: $e');
      throw Exception('Scores tablosu oluşturulamadı: $e');
    }
  }

  Future<List<UserScore>> fetchScores(String userId) async {
    try {
      debugPrint('Supabase\'den kullanıcı skorları alınıyor: $userId');

      // Supabase'in bağlantısını kontrol et
      bool isConnected = await testConnection();
      if (!isConnected) {
        debugPrint('Supabase bağlantısı kurulamadı, boş liste döndürülüyor');
        return [];
      }

      // Scores tablosunun varlığını kontrol et
      bool tableExists = await _checkIfTableExists('scores');
      if (!tableExists) {
        debugPrint(
          'Scores tablosu mevcut değil, tablonun oluşturulması deneniyor...',
        );
        try {
          // Tablo olmadığı için oluştur
          await _createScoresTableAlternative();
          debugPrint('Scores tablosu oluşturuldu, veri çekilecek');
        } catch (createError) {
          debugPrint('Tablo oluşturma hatası: $createError');
          return []; // Boş liste döndür
        }
      } else {
        debugPrint('Scores tablosu mevcut, veriler alınacak');
      }

      // Veriyi çekmeye çalış
      try {
        final response = await _supabaseClient
            .from('scores')
            .select()
            .eq('user_id', userId)
            .order('date', ascending: false);

        debugPrint(
          'Supabase\'den alınan skor verileri: ${(response as List).length} adet kayıt',
        );

        if ((response as List).isEmpty) {
          debugPrint('Kullanıcıya ait skor verisi bulunamadı.');
          return [];
        }

        final scores =
            (response as List)
                .map((score) => UserScore.fromMap(score))
                .toList();

        debugPrint('Dönüştürülen skor nesneleri: ${scores.length} adet');

        // Sonuçları doğrulama ve debug
        if (scores.isNotEmpty) {
          debugPrint('İlk skor örneği: ${scores.first.toMap()}');
        }

        return scores;
      } catch (fetchError) {
        debugPrint('Skorlar çekilirken özel hata: $fetchError');

        // Eğer tablo yapısı yanlış olabilir, önceden oluşturulan tabloda eksik alanlar olabilir
        if (fetchError.toString().contains('column') &&
            fetchError.toString().contains('does not exist')) {
          debugPrint(
            'Tablo yapısında sorun olabilir, yeniden oluşturmayı dene',
          );

          // Tabloyu silip yeniden oluşturmak gerekebilir, ancak bu veri kaybına yol açabilir
          // Bu nedenle boş liste döndürelim ve ilgili uyarıyı loglarla kaydedelim
          // İleriki bir sürümde, tabloyu uygun şekilde migrate edebiliriz

          return [];
        }

        return [];
      }
    } catch (e) {
      debugPrint('Skorlar alınırken genel hata: $e');
      // Uygulama çökmemesi için boş liste döndür
      return [];
    }
  }

  Future<List<UserScore>> fetchTopScores(int limit) async {
    try {
      final response = await _supabaseClient
          .from('scores')
          .select()
          .order('score', ascending: false)
          .limit(limit);

      return (response as List)
          .map((score) => UserScore.fromMap(score))
          .toList();
    } catch (e) {
      debugPrint('Error fetching top scores: $e');
      throw Exception('En yüksek skorlar yüklenirken bir hata oluştu: $e');
    }
  }

  // Kullanıcı profil bilgilerini Supabase'e kaydet
  Future<void> saveUserProfile(Map<String, dynamic> userData) async {
    try {
      final uid = userData['uid'];
      if (uid == null) {
        throw Exception('UID boş olamaz');
      }

      // Supabase'de bu kullanıcı var mı kontrol et
      final existingUser =
          await _supabaseClient
              .from('user_profiles')
              .select('uid')
              .eq('uid', uid)
              .maybeSingle();

      if (existingUser != null) {
        // Kullanıcı varsa güncelle
        await _supabaseClient
            .from('user_profiles')
            .update({
              'email': userData['email'],
              'display_name': userData['display_name'],
              'birth_date': userData['birth_date'],
              'birth_place': userData['birth_place'],
              'city': userData['city'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('uid', uid);
        debugPrint('Kullanıcı profili Supabase\'de güncellendi: $uid');
      } else {
        // Kullanıcı yoksa ekle
        await _supabaseClient.from('user_profiles').insert({
          'uid': uid,
          'email': userData['email'],
          'display_name': userData['display_name'],
          'birth_date': userData['birth_date'],
          'birth_place': userData['birth_place'],
          'city': userData['city'],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('Kullanıcı profili Supabase\'e eklendi: $uid');
      }
    } catch (e) {
      debugPrint('Kullanıcı profili Supabase\'e kaydedilirken hata: $e');
      throw Exception('Profil kaydedilirken bir hata oluştu: $e');
    }
  }

  // Kullanıcı profil bilgilerini Supabase'den getir
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final response =
          await _supabaseClient
              .from('user_profiles')
              .select()
              .eq('uid', uid)
              .maybeSingle();

      debugPrint('Supabase\'den alınan kullanıcı profili: $response');
      return response;
    } catch (e) {
      debugPrint('Kullanıcı profili Supabase\'den alınamadı: $e');
      return null;
    }
  }

  // Kullanıcının tamamladığı quiz sayısını getir
  Future<int> getCompletedQuizCount(String uid) async {
    try {
      final response = await _supabaseClient
          .from('scores')
          .select()
          .eq('user_id', uid);
      // Manuel olarak sayıyı hesapla
      final count = response.length;
      return count;
    } catch (e) {
      debugPrint('Tamamlanan quiz sayısı alınamadı: $e');
      return 0;
    }
  }

  // Kullanıcının en yüksek skorunu getir
  Future<int> getHighestScore(String uid) async {
    try {
      final response =
          await _supabaseClient
              .from('scores')
              .select('score')
              .eq('user_id', uid)
              .order('score', ascending: false)
              .limit(1)
              .maybeSingle();

      return response != null ? response['score'] ?? 0 : 0;
    } catch (e) {
      debugPrint('En yüksek skor alınamadı: $e');
      return 0;
    }
  }
}
