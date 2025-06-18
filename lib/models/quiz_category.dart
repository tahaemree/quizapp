class QuizCategory {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final String imagePath;

  const QuizCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.imagePath,
  });
}

class QuizCategories {
  static const cityPlates = QuizCategory(
    id: 'city_plates',
    name: 'Şehir Plakaları',
    description: 'Türkiye\'deki şehirlerin plaka kodlarını bilebilecek misin?',
    iconName: 'directions_car',
    imagePath: 'assets/city_plates.jpg',
  );

  static const cityRegions = QuizCategory(
    id: 'city_regions',
    name: 'Şehirler ve Bölgeler',
    description: 'Hangi şehir hangi bölgede bulunuyor?',
    iconName: 'map',
    imagePath: 'assets/city_regions.jpg',
  );

  static const citySpecialties = QuizCategory(
    id: 'city_specialties',
    name: 'Şehirlerin Meşhur Özellikleri',
    description: 'Hangi şehir nesiyle meşhur?',
    iconName: 'star',
    imagePath: 'assets/city_specialties.jpg',
  );

  static const historicalSites = QuizCategory(
    id: 'historical_sites',
    name: 'Tarihi Yapılar',
    description: 'Göbeklitepe, travertenler, peri bacaları hangi şehirde?',
    iconName: 'account_balance',
    imagePath: 'assets/historical_sites.jpg',
  );

  static const worldCapitals = QuizCategory(
    id: 'world_capitals',
    name: 'Dünya Başkentleri',
    description: 'Hangi ülkenin başkenti neresi?',
    iconName: 'public',
    imagePath: 'assets/world_capitals.jpg',
  );

  static List<QuizCategory> allCategories = [
    cityPlates,
    cityRegions,
    citySpecialties,
    historicalSites,
    worldCapitals,
  ];
}
