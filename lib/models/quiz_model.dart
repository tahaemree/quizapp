class QuestionModel {
  final int? id;
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final String category;
  final String? imageUrl;

  QuestionModel({
    this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.category,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question_text': questionText,
      'options': options.join('|'), // For SQLite storage
      'correct_answer': correctAnswer,
      'category': category,
      'image_url': imageUrl,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'question_text': questionText,
      'options': options, // Supabase will store this as JSON
      'correct_answer': correctAnswer,
      'category': category,
      'image_url': imageUrl,
    };
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'],
      questionText: map['question_text'] ?? '',
      options: _parseOptions(map['options']),
      correctAnswer: map['correct_answer'] ?? '',
      category: map['category'] ?? 'Genel',
      imageUrl: map['image_url'],
    );
  }

  static List<String> _parseOptions(dynamic options) {
    if (options is List) {
      return options.map((e) => e.toString()).toList();
    } else if (options is String) {
      return options.split('|');
    }
    return [];
  }
}

class UserScore {
  final int? id;
  final String userId;
  final int score;
  final DateTime date;
  final String categoryId;
  final String categoryName;
  final int totalQuestions;
  final int scorePercent;

  UserScore({
    this.id,
    required this.userId,
    required this.score,
    required this.date,
    this.categoryId = 'general',
    this.categoryName = 'Genel',
    this.totalQuestions = 10,
    this.scorePercent = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'score': score,
      'date': date.toIso8601String(),
      'category_id': categoryId,
      'category_name': categoryName,
      'total_questions': totalQuestions,
      'score_percent': scorePercent,
    };
  }

  factory UserScore.fromMap(Map<String, dynamic> map) {
    return UserScore(
      id: map['id'],
      userId: map['user_id'] ?? '',
      score: map['score'] ?? 0,
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      categoryId: map['category_id'] ?? 'general',
      categoryName: map['category_name'] ?? 'Genel',
      totalQuestions: map['total_questions'] ?? 10,
      scorePercent: map['score_percent'] ?? 0,
    );
  }
}
