import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  String _currentLanguage = 'tagalog';
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Translations map
  static const Map<String, Map<String, String>> _translations = {
    'tagalog': {
      // Profiling
      'selectCategory': 'Pumili ng Category',
      'elderly': 'Elderly',
      'highRisk': 'High-Risk',
      'balanceStability': 'Nahihirapan ka bang panatilihin ang balanse habang naglalakad?',
      'obstacleCollision': 'Nakararanas ka ba ng banggaan sa mga bagay habang naglalakad?',
      'indoorDifficulty': 'Nahihirapan ka bang gumalaw sa loob ng bahay o gusali?',
      'voicePreference': 'Mas nakakatulong ba sa iyo ang nagsasalitang babala?',
      'vibrationNeed': 'Mas ramdam mo ba ang babala kapag may vibration?',
      'walkingFatigue': 'Madali ka bang mapagod kapag naglalakad?',
      'preferredLanguage': 'Ano ang iyong preferred language?',
      'tagalog': 'Tagalog',
      'english': 'English',
      'oo': 'Oo',
      'hindi': 'Hindi',
      'madalas': 'Madalas',
      'paminsanMinsan': 'Paminsan-minsan',
      'bihira': 'Bihira',
      // High-risk
      'headLevelObstacle': 'Nakararanas ka ba ng banggaan sa mga bagay na nasa antas ng ulo o dibdib?',
      'preferredWarningType': 'Alin ang mas epektibong babala para sa iyo?',
      'continuousAssistance': 'Kailangan mo ba ng tuloy-tuloy na babala habang naglalakad?',
      'unevenTerrain': 'Nakararanas ka ba ng biglaang pagbaba o hukay sa dinaanan?',
      'terrainVoiceWarning': 'Gusto mo bang may voice alert kapag may lalim o panganib?',
      'terrainVibrationAlert': 'Mas gusto mo bang may vibration kasabay ng babala sa terrain?',
      'voiceLamang': 'Voice lamang',
      'vibrationLamang': 'Vibration lamang',
      'pareho': 'Pareho',
      // Settings
      'settings': 'Settings',
      'languagePreference': 'Language Preference',
      'textSize': 'Text Size',
      'hardwareComponents': 'Hardware Components',
      'appTheme': 'App Theme',
      'darkMode': 'Dark Mode',
      'lightMode': 'Light Mode',
      'saveSetting': 'Save Setting',
      // Home
      'home': 'HOME',
      'profiling': 'Profiling',
      'map': 'Map',
    },
    'english': {
      // Profiling
      'selectCategory': 'Select Category',
      'elderly': 'Elderly',
      'highRisk': 'High-Risk',
      'balanceStability': 'Do you have difficulty maintaining balance while walking?',
      'obstacleCollision': 'Do you experience collisions with objects while walking?',
      'indoorDifficulty': 'Do you have difficulty moving inside the house or building?',
      'voicePreference': 'Is speaking English more helpful to you?',
      'vibrationNeed': 'Do you feel the alert better when there is vibration?',
      'walkingFatigue': 'Do you get tired easily when walking?',
      'preferredLanguage': 'What is your preferred language?',
      'tagalog': 'Tagalog',
      'english': 'English',
      'oo': 'Yes',
      'hindi': 'No',
      'madalas': 'Often',
      'paminsanMinsan': 'Sometimes',
      'bihira': 'Rarely',
      // High-risk
      'headLevelObstacle': 'Do you experience collisions with objects at head or chest level?',
      'preferredWarningType': 'Which warning is more effective for you?',
      'continuousAssistance': 'Do you need continuous warnings while walking?',
      'unevenTerrain': 'Do you experience sudden drops or holes in your path?',
      'terrainVoiceWarning': 'Do you want voice alerts when there is depth or danger?',
      'terrainVibrationAlert': 'Do you prefer vibration along with terrain warnings?',
      'voiceLamang': 'Voice only',
      'vibrationLamang': 'Vibration only',
      'pareho': 'Both',
      // Settings
      'settings': 'Settings',
      'languagePreference': 'Language Preference',
      'textSize': 'Text Size',
      'hardwareComponents': 'Hardware Components',
      'appTheme': 'App Theme',
      'darkMode': 'Dark Mode',
      'lightMode': 'Light Mode',
      'saveSetting': 'Save Setting',
      // Home
      'home': 'HOME',
      'profiling': 'Profiling',
      'map': 'Map',
    },
  };

  // Get translation
  String translate(String key) {
    return _translations[_currentLanguage]?[key] ?? key;
  }

  // Get current language
  String get currentLanguage => _currentLanguage;

  // Load language from Firebase
  Future<void> loadLanguage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await _database.child('profiling').child(user.uid).child('language').get();
        if (snapshot.exists) {
          final lang = snapshot.value as String?;
          if (lang != null && (lang == 'tagalog' || lang == 'english')) {
            _currentLanguage = lang;
          }
        }
      }
    } catch (e) {
      print('Error loading language: $e');
    }
  }

  // Set language
  void setLanguage(String language) {
    if (language == 'tagalog' || language == 'english') {
      _currentLanguage = language;
    }
  }
}

