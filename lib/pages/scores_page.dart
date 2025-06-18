import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/quiz_model.dart';
import '../widgets/base_page.dart';

class ScoresPage extends StatefulWidget {
  const ScoresPage({super.key});

  @override
  State<ScoresPage> createState() => _ScoresPageState();
}

class _ScoresPageState extends State<ScoresPage> {
  final SupabaseService _supabaseService = SupabaseService();
  List<UserScore> _scores = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _getUserIdAndLoadScores();
  }

  Future<void> _getUserIdAndLoadScores() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    setState(() {
      _userId = uid;
    });

    if (_userId != null) {
      await _loadScores();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadScores() async {
    try {
      if (_userId == null) return;

      debugPrint('Skorlar yükleniyor, kullanıcı ID: $_userId');

      // Önce test bağlantısı yap
      bool isConnected = await _supabaseService.testConnection();
      if (!isConnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Supabase\'e bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Supabase'den skorlar alınıyor
      final scores = await _supabaseService.fetchScores(_userId!);

      if (mounted) {
        setState(() {
          _scores = scores;
          _isLoading = false;
        });
      }

      debugPrint('${scores.length} adet skor yüklendi');

      // Eğer skorlar boşsa ve Supabase bağlantısı varsa, kullanıcıya haber ver
      if (scores.isEmpty && isConnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Henüz kayıtlı skorunuz bulunmuyor. Bir test çözün ve skorunuz burada görünecek.',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Skorlar yüklenirken hata: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _scores = []; // Hata durumunda boş liste göster
        });

        // Kullanıcıya göster ancak daha az rahatsız edici şekilde
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Skorlarınız yüklenirken bir sorun oluştu. Lütfen daha sonra tekrar deneyin.',
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: _loadScores,
            ),
          ),
        );
      }
    }
  }

  // Kullanıcı istatistiklerini yükleyen metod
  Future<Map<String, dynamic>> _loadUserStats() async {
    if (_userId == null) {
      return {'completedQuizzes': 0, 'highestScore': 0, 'averageScore': 0.0};
    }

    try {
      // Tamamlanan quiz sayısı
      final completedQuizzes = await _supabaseService.getCompletedQuizCount(
        _userId!,
      );

      // En yüksek skor
      final highestScore = await _supabaseService.getHighestScore(_userId!);

      // Ortalama skor hesapla
      double averageScore = 0.0;
      if (_scores.isNotEmpty) {
        int total = _scores.fold(0, (sum, score) => sum + score.score);
        averageScore = total / _scores.length;
      }

      return {
        'completedQuizzes': completedQuizzes,
        'highestScore': highestScore,
        'averageScore': averageScore,
      };
    } catch (e) {
      debugPrint('Kullanıcı istatistiklerini yüklerken hata: $e');
      return {'completedQuizzes': 0, 'highestScore': 0, 'averageScore': 0.0};
    }
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      title: 'Skorlarım',
      content:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userId == null
              ? const Center(
                child: Text('Skorlarınızı görmek için lütfen giriş yapın'),
              )
              : _buildScoresContent(),
    );
  }

  Widget _buildScoresContent() {
    if (_scores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Henüz Skor Yok',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Skorlarınızı görmek için bir test çözün',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/quiz');
              },
              child: const Text('Test Çöz'),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUserStats(),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ??
            {
              'completedQuizzes': _scores.length,
              'highestScore':
                  _scores.isNotEmpty
                      ? _scores
                          .map((s) => s.score)
                          .reduce((a, b) => a > b ? a : b)
                      : 0,
              'averageScore':
                  _scores.isNotEmpty
                      ? _scores.fold(0, (sum, s) => sum + s.score) /
                          _scores.length
                      : 0.0,
            };

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // İstatistik kartları
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'İstatistikleriniz',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          context,
                          'Tamamlanan Test',
                          '${stats['completedQuizzes']}',
                          Icons.check_circle,
                        ),
                        _buildStatItem(
                          context,
                          'En Yüksek Skor',
                          '${stats['highestScore']} Puan',
                          Icons.emoji_events,
                        ),
                        _buildStatItem(
                          context,
                          'Ortalama Skor',
                          '${stats['averageScore'].toStringAsFixed(1)}',
                          Icons.trending_up,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Test Geçmişiniz',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Toplam çözülen test: ${_scores.length}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(0),
                    itemCount: _scores.length,
                    separatorBuilder:
                        (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final score = _scores[index];
                      final dateFormat = DateFormat('MMM dd, yyyy - HH:mm');
                      final formattedDate = dateFormat.format(
                        score.date,
                      ); // Skora göre renk belirle (10 puan sistemine göre ayarlandı)
                      Color scoreColor;
                      if (score.score >= 80) {
                        scoreColor = Colors.green;
                      } else if (score.score >= 60) {
                        scoreColor = Colors.blue;
                      } else if (score.score >= 40) {
                        scoreColor = Colors.orange;
                      } else {
                        scoreColor = Colors.red;
                      }
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: scoreColor,
                          child: Text(
                            '${score.score}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              'Skor: ${score.score}/${score.totalQuestions * 10} Puan',
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scoreColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '%${score.scorePercent}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: scoreColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(score.categoryName),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        //trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Test hakkında daha fazla detay gösterilebilir
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Kullanıcının istatistiklerini gösteren widget
  Widget _buildStatItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }
}
