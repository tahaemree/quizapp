import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../models/quiz_model.dart';

class SQLiteService {
  static final SQLiteService _instance = SQLiteService._internal();
  static Database? _database;

  factory SQLiteService() {
    return _instance;
  }

  SQLiteService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    debugPrint('SQLite veritabanı başlatılıyor...');

    // SQLite FFI'yi başlat (Windows/Linux için)
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      return await databaseFactoryFfi.openDatabase(
        join(await getDatabasesPath(), 'quizapp.db'),
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createTables,
          onUpgrade: _upgradeDatabase,
        ),
      );
    }

    // Mobil platformlar için normal SQLite'ı kullan
    return await openDatabase(
      join(await getDatabasesPath(), 'quizapp.db'),
      version: 1,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    debugPrint('SQLite tabloları oluşturuluyor...');

    // Kullanıcı tablosu
    await db.execute('''
      CREATE TABLE users(
        uid TEXT PRIMARY KEY,
        email TEXT,
        display_name TEXT,
        birth_date TEXT,
        birth_place TEXT,
        city TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    // Skorlar tablosu
    await db.execute('''
      CREATE TABLE scores(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        score INTEGER,
        date TEXT,
        category_id TEXT,
        category_name TEXT,
        total_questions INTEGER,
        score_percent INTEGER,
        FOREIGN KEY (user_id) REFERENCES users (uid)
      )
    ''');

    debugPrint('SQLite tabloları başarıyla oluşturuldu');
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    debugPrint('SQLite veritabanı güncelleniyor: $oldVersion -> $newVersion');

    // Gelecekte veritabanı yapısı değişirse burada güncelleme yapılacak
    if (oldVersion < 2) {
      // Versiyon 2'ye güncelleme
    }
  }

  // Kullanıcı işlemleri
  Future<void> saveUser(UserModel user) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Userdata hazırla
      final userData = {
        'uid': user.uid,
        'email': user.email,
        'display_name': user.displayName,
        'birth_date': user.birthDate,
        'birth_place': user.birthPlace,
        'city': user.city,
        'created_at': now,
        'updated_at': now,
      };

      // Conflict algoritması: Varsa güncelle, yoksa ekle
      await db.insert(
        'users',
        userData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('Kullanıcı SQLite veritabanına kaydedildi: ${user.uid}');
    } catch (e) {
      debugPrint('SQLite kullanıcı kaydetme hatası: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final db = await database;
      final maps = await db.query('users', where: 'uid = ?', whereArgs: [uid]);

      if (maps.isNotEmpty) {
        return UserModel.fromMap({
          'uid': maps[0]['uid'] as String,
          'email': maps[0]['email'] as String,
          'display_name': maps[0]['display_name'] as String,
          'birth_date': maps[0]['birth_date'] as String,
          'birth_place': maps[0]['birth_place'] as String,
          'city': maps[0]['city'] as String,
        });
      }
      return null;
    } catch (e) {
      debugPrint('SQLite kullanıcı getirme hatası: $e');
      return null;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final db = await database;
      final maps = await db.query('users');

      return List.generate(maps.length, (index) {
        return UserModel.fromMap({
          'uid': maps[index]['uid'] as String,
          'email': maps[index]['email'] as String,
          'display_name': maps[index]['display_name'] as String,
          'birth_date': maps[index]['birth_date'] as String,
          'birth_place': maps[index]['birth_place'] as String,
          'city': maps[index]['city'] as String,
        });
      });
    } catch (e) {
      debugPrint('SQLite tüm kullanıcıları getirme hatası: $e');
      return [];
    }
  }

  // Skor işlemleri
  Future<int> saveScore(UserScore score) async {
    try {
      final db = await database;

      final scoreData = {
        'user_id': score.userId,
        'score': score.score,
        'date': score.date.toIso8601String(),
        'category_id': score.categoryId,
        'category_name': score.categoryName,
        'total_questions': score.totalQuestions,
        'score_percent': score.scorePercent,
      };

      final id = await db.insert('scores', scoreData);
      debugPrint('Skor SQLite veritabanına kaydedildi, ID: $id');
      return id;
    } catch (e) {
      debugPrint('SQLite skor kaydetme hatası: $e');
      return -1;
    }
  }

  Future<List<UserScore>> getScoresByUser(String userId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'scores',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'date DESC',
      );

      return List.generate(maps.length, (index) {
        return UserScore.fromMap({
          'id': maps[index]['id'] as int,
          'user_id': maps[index]['user_id'] as String,
          'score': maps[index]['score'] as int,
          'date': maps[index]['date'] as String,
          'category_id': maps[index]['category_id'] as String,
          'category_name': maps[index]['category_name'] as String,
          'total_questions': maps[index]['total_questions'] as int,
          'score_percent': maps[index]['score_percent'] as int,
        });
      });
    } catch (e) {
      debugPrint('SQLite kullanıcı skorları getirme hatası: $e');
      return [];
    }
  }
}
