#pragma once

#include <QObject>
#include <QTranslator>
#include <QGuiApplication>
#include <QLocale>
#include <QSettings>
#include <QQmlEngine>

class TranslationManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentLanguage READ currentLanguage WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QStringList availableLanguages READ availableLanguages CONSTANT)
    Q_PROPERTY(int languageVersion READ languageVersion NOTIFY languageChanged)

public:
    explicit TranslationManager(QGuiApplication *app, QObject *parent = nullptr);
    ~TranslationManager() override;

    void setEngine(QQmlEngine *engine) { m_engine = engine; }

    QString currentLanguage() const;
    QStringList availableLanguages() const;
    int languageVersion() const { return m_languageVersion; }

    Q_INVOKABLE void setLanguage(const QString &language);
    Q_INVOKABLE QString getLanguageName(const QString &language) const;

signals:
    void languageChanged();

private:
    void loadTranslation(const QString &language);
    QString getSystemLanguage() const;
    void saveLanguagePreference(const QString &language);
    QString loadLanguagePreference() const;

    QGuiApplication *m_app;
    QQmlEngine *m_engine = nullptr;
    QTranslator *m_translator;
    QString m_currentLanguage;
    QSettings m_settings;
    int m_languageVersion = 0;

    static const QMap<QString, QString> m_languageNames;
};
