import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../models/quiz_model.dart';
import '../models/quiz_category.dart';
import '../widgets/base_page.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final SupabaseService _supabaseService = SupabaseService();
  List<QuestionModel> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _isAnswered = false;
  bool _isQuizCompleted = false;
  String? _selectedOption;
  String? _userId;
  String? _categoryId;
  QuizCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _getUserIdFromPrefs();
    // Soruların yüklenmesi didChangeDependencies'e taşındı
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Route argümanlarını al
    final Map<String, dynamic>? args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null && args.containsKey('category')) {
      _categoryId = args['category'] as String;
      _selectedCategory = _getCategoryById(_categoryId!);
      _loadQuestionsByCategory(_categoryId!);
    } else {
      // Kategori seçilmediyse tüm soruları yükle
      _loadQuestions();
    }
  }

  QuizCategory? _getCategoryById(String categoryId) {
    try {
      return QuizCategories.allCategories.firstWhere(
        (cat) => cat.id == categoryId,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _getUserIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('uid');
    });
  }

  Future<void> _loadQuestionsByCategory(String categoryId) async {
    setState(() {
      _isLoading = true;
      _questions = [];
    });

    try {
      final questions = await _supabaseService.fetchQuestionsByCategory(
        categoryId,
        10,
      );
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Sorular yüklenirken bir hata oluştu: $e');
    }
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _questions = [];
    });

    try {
      final questions = await _supabaseService.fetchRandomQuestions(10);
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Sorular yüklenirken bir hata oluştu');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hata'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (_questions.isEmpty) {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },
                child: const Text('Tamam'),
              ),
            ],
          ),
    );
  }

  void _checkAnswer(String selectedOption) {
    if (_isAnswered) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = selectedOption == currentQuestion.correctAnswer;

    setState(() {
      _isAnswered = true;
      _selectedOption = selectedOption;
      if (isCorrect) {
        // Her doğru cevap için 10 puan ekle
        _score += 10;
      }
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _isAnswered = false;
          _selectedOption = null;
        });
      } else {
        setState(() {
          _isQuizCompleted = true;
        });
        _saveScore();
      }
    });
  }

  Future<void> _saveScore() async {
    if (_userId != null) {
      try {
        // Quiz kategorisi bilgisi
        final categoryName = _selectedCategory?.name ?? 'Genel';
        final categoryId =
            _selectedCategory?.id ??
            'general'; // Quiz tamamlanma yüzdesi - 10 puan üzerinden hesaplama
        final scorePercent = (_score / (_questions.length * 10)) * 100;

        debugPrint(
          'Quiz tamamlandı! Skor kaydediliyor: $_score/${_questions.length * 10} Puan',
        );
        debugPrint(
          'Kategori: $categoryName, Başarı Yüzdesi: ${scorePercent.round()}%',
        );

        // Supabase'e skoru kaydet ve kategorik bilgiler ekle - daha fazla debug bilgisi için verbose log
        debugPrint(
          'SKOR KAYIT BAŞLANGICI: userId=$_userId, score=$_score, kategori=$categoryName',
        );

        await _supabaseService.saveScore(
          _userId!,
          _score,
          categoryId: categoryId,
          categoryName: categoryName,
          totalQuestions: _questions.length,
          scorePercent: scorePercent.round(),
        );
        debugPrint(
          '✅ SKOR BAŞARIYLA KAYDEDİLDİ: $_score/${_questions.length * 10} Puan - $categoryName',
        );

        // Skoru kaydettikten sonra ScoresPage'i açmak istiyorsak burada yapabiliriz
      } catch (e) {
        debugPrint('❌ SKOR KAYIT HATASI: $e');

        // Hata oluştuğunda kullanıcıya bilgi ver (opsiyonel)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Skor kaydedilirken bir hata oluştu. Skorlar sayfasında görünmeyebilir.',
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else {
      debugPrint(
        '❌ KRİTİK HATA: Kullanıcı ID\'si bulunamadı, skor kaydedilemedi!',
      );

      // Kritik hata durumunda kullanıcıyı bilgilendir
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kullanıcı bilgisi bulunamadığı için skorunuz kaydedilemedi. Lütfen tekrar giriş yapın.',
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Giriş Yap',
              onPressed:
                  () => Navigator.pushReplacementNamed(context, '/login'),
              textColor: Colors.white,
            ),
          ),
        );
      }

      // Kullanıcı ID'sinin alınamamasının sebebi SharedPrefs okuma hatası olabilir
      // Yeniden okumayı dene
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedUid = prefs.getString('uid');
        debugPrint(
          'Yeniden okuma denemesi - SharedPrefs\'teki UID: $storedUid',
        );
      } catch (e) {
        debugPrint('SharedPrefs okuma hatası: $e');
      }
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _score = 0;
      _isAnswered = false;
      _isQuizCompleted = false;
      _selectedOption = null;
      _isLoading = true;
    });

    if (_categoryId != null) {
      _loadQuestionsByCategory(_categoryId!);
    } else {
      _loadQuestions();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kategori başlığını belirle
    String title = 'Quiz';
    if (_selectedCategory != null) {
      title = _selectedCategory!.name;
    }

    return BasePage(
      title: title,
      content:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isQuizCompleted
              ? _buildResultScreen()
              : _buildQuizContent(),
    );
  }

  Widget _buildResultScreen() {
    return _buildQuizCompleted();
  }

  Widget _buildQuizContent() {
    if (_questions.isEmpty) {
      return const Center(
        child: Text(
          'Bu kategoride hiç soru bulunamadı.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicators
          Row(
            children: [
              Text(
                'Soru ${_currentQuestionIndex + 1}/${_questions.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Skor: $_score/${_questions.length * 10} Puan',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 20),

          // Question
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                currentQuestion.questionText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (currentQuestion.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  currentQuestion.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Center(child: Text('Resim yüklenemedi')),
                    );
                  },
                ),
              ),
            ),

          // Options
          ...currentQuestion.options.map((option) {
            final isSelected = _selectedOption == option;
            final isCorrect = currentQuestion.correctAnswer == option;
            final showCorrect = _isAnswered && isCorrect;
            final showIncorrect = _isAnswered && isSelected && !isCorrect;

            Color buttonColor = Colors.white;
            if (showCorrect) {
              buttonColor = Colors.green.shade100;
            } else if (showIncorrect) {
              buttonColor = Colors.red.shade100;
            } else if (isSelected) {
              buttonColor = Colors.blue.shade100;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ElevatedButton(
                onPressed: _isAnswered ? () {} : () => _checkAnswer(option),
                // Disabled state'i kaldırdım ve tıklanamazlığı koruyarak görünür kalmalarını sağladım
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor:
                      Colors.black87, // Şık metni için koyu renk ekledim
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  option,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuizCompleted() {
    // Yüzde hesaplaması kaldırıldı, sadece ham skor gösteriliyor

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              'Test Tamamlandı!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Skorunuz: $_score',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: _restartQuiz,
                child: const Text('Tekrar Dene'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/home');
                },
                child: const Text('Ana Sayfaya Dön'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/scores');
                },
                child: const Text('Tüm Skorlarım'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Skorunuz kaydedildi!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
