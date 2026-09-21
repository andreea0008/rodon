#include "TranslationManager.h"
#include <QCoreApplication>
#include <QDebug>

const QMap<QString, QString> TranslationManager::m_languageNames = {
    {"en", "English"},     {"uk", "Українська"},       {"ru", "Русский"},
    {"de", "Deutsch"},     {"sk", "Slovenčina"},       {"pl", "Polski"},
    {"fr", "Français"},    {"ja", "日本語"},           {"zh", "中文"},
    {"ko", "한국어"},      {"es", "Español"},          {"pt", "Português"},
    {"tr", "Türkçe"},      {"ar", "العربية"},          {"vi", "Tiếng Việt"},
    {"th", "ไทย"},         {"id", "Bahasa Indonesia"}, {"cs", "Čeština"},
    {"sl", "Slovenščina"}, {"it", "Italiano"}};

TranslationManager::TranslationManager(QGuiApplication *app, QObject *parent)
    : QObject(parent), m_app(app), m_translator(new QTranslator(this)),
      m_settings("vpn", "rodon") {
  // Load saved language preference or use system language
  QString savedLanguage = loadLanguagePreference();
  if (savedLanguage.isEmpty() || savedLanguage == "auto") {
    m_currentLanguage = "auto";
    loadTranslation(getSystemLanguage());
  } else if (m_languageNames.contains(savedLanguage)) {
    m_currentLanguage = savedLanguage;
    loadTranslation(savedLanguage);
  } else {
    m_currentLanguage = "auto";
    loadTranslation(getSystemLanguage());
  }
}

TranslationManager::~TranslationManager() {
  if (m_translator) {
    m_app->removeTranslator(m_translator);
  }
}

QString TranslationManager::currentLanguage() const {
  return m_currentLanguage;
}

QStringList TranslationManager::availableLanguages() const {
  QStringList langs;
  langs << "auto";
  langs << m_languageNames.keys();
  return langs;
}

void TranslationManager::setLanguage(const QString &language) {
  qDebug() << m_currentLanguage << language;
  if (m_currentLanguage == language) {
    return;
  }

  QString loadLang = language;
  if (language == "auto") {
    loadLang = getSystemLanguage();
  }

  if (language != "auto" && !m_languageNames.contains(language)) {
    return;
  }

  loadTranslation(loadLang);
  m_currentLanguage = language; // store "auto" or specific code
  m_languageVersion++;
  saveLanguagePreference(language);

  if (m_engine) {
    m_engine->retranslate();
  }

  emit languageChanged();
}

QString TranslationManager::getLanguageName(const QString &language) const {
  if (language == "auto") {
    return tr("Auto");
  }
  return m_languageNames.value(language, language);
}

void TranslationManager::loadTranslation(const QString &language) {
  // Remove previous translation
  if (m_translator) {
    m_app->removeTranslator(m_translator);
    delete m_translator;
    m_translator = new QTranslator(this);
  }

  // English is the source language - no translation file needed
  if (language == "en") {
    qDebug() << "Using English (source language) - no translation file loaded";
    return;
  }

  // Load new translation
  QString translationFile = QString("rodon_%1").arg(language);
  QString appDir = QCoreApplication::applicationDirPath();

  qDebug() << "Attempting to load translation:" << translationFile;
  qDebug() << "Application directory:" << appDir;

  bool loaded = false;

  // Try to load from resources first (embedded in executable)
  if (m_translator->load(translationFile, ":/i18n")) {
    qDebug() << "✓ Loaded translation from resources:" << translationFile;
    loaded = true;
  }
  // Try to load from i18n subdirectory (copied by CMake)
  else if (m_translator->load(translationFile, appDir + "/i18n")) {
    qDebug() << "✓ Loaded translation from i18n directory:" << translationFile;
    loaded = true;
  }
  // Try to load from app directory
  else if (m_translator->load(translationFile, appDir)) {
    qDebug() << "✓ Loaded translation from app directory:" << translationFile;
    loaded = true;
  }
  // Try to load from build directory parent (for development)
  else if (m_translator->load(translationFile, appDir + "/..")) {
    qDebug() << "✓ Loaded translation from parent directory:"
             << translationFile;
    loaded = true;
  }
  // Try to load from build directory (for development)
  else if (m_translator->load(appDir + "/../" + translationFile + ".qm")) {
    qDebug() << "✓ Loaded translation from build directory:" << translationFile;
    loaded = true;
  } else {
    qWarning() << "✗ Failed to load translation:" << translationFile;
    qWarning() << "Searched in:";
    qWarning() << "  - :/i18n/" + translationFile;
    qWarning() << "  - " + appDir + "/i18n/" + translationFile;
    qWarning() << "  - " + appDir + "/" + translationFile;
    qWarning() << "  - " + appDir + "/../" + translationFile;
    qWarning() << "  - " + appDir + "/../" + translationFile + ".qm";
  }

  if (loaded) {
    m_app->installTranslator(m_translator);
  }
}

QString TranslationManager::getSystemLanguage() const {
  // Get system locale (e.g., "uk_UA", "en_US", "ru_RU", "de_DE")
  QString systemLocale = QLocale::system().name();
  QString languageCode =
      systemLocale.split('_').first(); // e.g., "uk", "en", "ru", "de"

  qDebug() << "System locale:" << systemLocale
           << "Language code:" << languageCode;

  // Check if we have exact language code match
  if (m_languageNames.contains(languageCode)) {
    qDebug() << "Found matching language:" << languageCode;
    return languageCode;
  }

  // Try to get language from QLocale
  QLocale systemQLocale = QLocale::system();
  QLocale::Language language = systemQLocale.language();

  // Map QLocale::Language to our language codes
  switch (language) {
  case QLocale::Ukrainian:
    qDebug() << "Detected Ukrainian from QLocale";
    return "uk";
  case QLocale::Russian:
    qDebug() << "Detected Russian from QLocale";
    return "ru";
  case QLocale::German:
    qDebug() << "Detected German from QLocale";
    return "de";
  case QLocale::Slovak:
    qDebug() << "Detected Slovak from QLocale";
    return "sk";
  case QLocale::Polish:
    qDebug() << "Detected Polish from QLocale";
    return "pl";
  case QLocale::French:
    qDebug() << "Detected French from QLocale";
    return "fr";
  case QLocale::Japanese:
    qDebug() << "Detected Japanese from QLocale";
    return "ja";
  case QLocale::Chinese:
    qDebug() << "Detected Chinese from QLocale";
    return "zh";
  case QLocale::Korean:
    qDebug() << "Detected Korean from QLocale";
    return "ko";
  case QLocale::Spanish:
    qDebug() << "Detected Spanish from QLocale";
    return "es";
  case QLocale::Portuguese:
    qDebug() << "Detected Portuguese from QLocale";
    return "pt";
  case QLocale::Turkish:
    qDebug() << "Detected Turkish from QLocale";
    return "tr";
  case QLocale::Arabic:
    qDebug() << "Detected Arabic from QLocale";
    return "ar";
  case QLocale::Vietnamese:
    qDebug() << "Detected Vietnamese from QLocale";
    return "vi";
  case QLocale::Thai:
    qDebug() << "Detected Thai from QLocale";
    return "th";
  case QLocale::Indonesian:
    qDebug() << "Detected Indonesian from QLocale";
    return "id";
  case QLocale::Czech:
    qDebug() << "Detected Czech from QLocale";
    return "cs";
  case QLocale::Slovenian:
    qDebug() << "Detected Slovenian from QLocale";
    return "sl";
  case QLocale::English:
    qDebug() << "Detected English from QLocale";
    return "en";
  case QLocale::Italian:
    return "it";
  default:
    qDebug() << "No match found, defaulting to English";
    return "en";
  }
}

void TranslationManager::saveLanguagePreference(const QString &language) {
  m_settings.setValue("language", language);
}

QString TranslationManager::loadLanguagePreference() const {
  return m_settings.value("language", QString()).toString();
}
