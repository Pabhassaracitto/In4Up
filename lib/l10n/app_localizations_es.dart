// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get commandCenter => 'CENTRO DE MANDO';

  @override
  String get knowledgeOS => 'Sistema Operativo de Conocimiento';

  @override
  String get manageAIModels => 'Gestionar modelos de IA';

  @override
  String loginFailed(String error) {
    return 'Error de inicio de sesión: $error';
  }

  @override
  String get studioRoom => 'SALA DE ESTUDIO';

  @override
  String get listen => 'ESCUCHAR';

  @override
  String get read => 'LEER';

  @override
  String get understand => 'ENTENDER';

  @override
  String get remember => 'RECORDAR';

  @override
  String get quickNote => 'Nota Rápida';

  @override
  String get listening => 'Escuchando...';

  @override
  String get done => 'Hecho';

  @override
  String get wordList => 'Lista de Palabras';

  @override
  String get wordListSubtitle => 'Lista de vocabulario';

  @override
  String get timeline => 'Línea de Tiempo';

  @override
  String get timelineSubtitle => 'Línea de tiempo de aprendizaje';

  @override
  String get wordListStats => 'Estadísticas de Palabras';

  @override
  String get wordListStatsSubtitle => 'Estadísticas detalladas';

  @override
  String get webReader => 'Lector Web';

  @override
  String get webReaderSubtitle => 'Lectura Web + CEFR';

  @override
  String get youtube => 'YouTube';

  @override
  String get youtubeSubtitle => 'Explorar canales en inglés';

  @override
  String get pdfReader => 'Lector de PDF';

  @override
  String get pdfReaderSubtitle => 'Abrir y leer archivos PDF';

  @override
  String get youglish => 'YouGlish';

  @override
  String get youglishSubtitle => 'Pronunciación nativa';

  @override
  String get overview => 'Resumen';

  @override
  String get overviewSubtitle => 'Progreso de aprendizaje';

  @override
  String get wordMap => 'Mapa de Palabras';

  @override
  String get wordMapSubtitle => 'Conocido → Pequeño · Desconocido → Grande';

  @override
  String get triangle => 'Triángulo';

  @override
  String get triangleSubtitle => 'Mapa + Evaluación rápida';

  @override
  String get vennDiagram => 'Diagrama de Venn';

  @override
  String get vennDiagramSubtitle => 'Zonas de habilidades';

  @override
  String get review => 'Repasar';

  @override
  String get reviewSubtitle => 'Repetición espaciada SM-2';

  @override
  String get shadowing => 'Shadowing';

  @override
  String get shadowingSubtitle => 'Práctica de Shadowing';

  @override
  String get dictation => 'Dictado';

  @override
  String get dictationSubtitle => 'Escuchar y escribir';

  @override
  String get audioLibrary => 'Biblioteca de Audio';

  @override
  String get home => 'Inicio';

  @override
  String get tools => 'Herramientas';

  @override
  String get nowPlaying => 'Reproduciendo';

  @override
  String get typeVocabulary => 'Vocabulario';

  @override
  String get typePhrase => 'Frase';

  @override
  String get typeSentence => 'Oración';

  @override
  String get typeParagraph => 'Párrafo';

  @override
  String get typeDharma => 'Dharma';

  @override
  String get typeGrammar => 'Gramática';

  @override
  String get diffEasy => 'Fácil';

  @override
  String get diffMedium => 'Medio';

  @override
  String get diffHard => 'Difícil';

  @override
  String get vocabWord => 'Palabra';

  @override
  String get vocabPhrase => 'Frase';

  @override
  String get vocabSentence => 'Oración';

  @override
  String get vocabParagraph => 'Párrafo';
}
