#pragma once

#include <QDateTime>
#include <QDebug>
#include <QJsonObject>
#include <QObject>

struct AccountMe {
  QString id, plan;
  QDateTime createdAt;
  bool emailVerified = false;

  void print() const {
    qDebug().noquote() << "─── AccountMe ──────────────────────────────";
    qDebug().noquote() << "  id:             "
                       << (id.isEmpty() ? QStringLiteral("<empty>") : id);
    qDebug().noquote() << "  plan:           "
                       << (plan.isEmpty() ? QStringLiteral("<empty>") : plan);
    qDebug().noquote() << "  emailVerified:  "
                       << (emailVerified ? "true" : "false");
    qDebug().noquote() << "  createdAt:      "
                       << (createdAt.isValid() ? createdAt.toString(Qt::ISODate)
                                               : QStringLiteral("<invalid>"));
    qDebug().noquote() << "────────────────────────────────────────────";
  }
};

struct Device {
  QString id;
  QString device_id;
  QString name;
  QString platform;
  QDateTime createdAt;
  QDateTime lastSeenAt;
};

struct Location {
  QString id, countryCode, countryName, city, tier;
  double loadFactor;
  bool available;

  Location() = default;
  Location(const QString &Id, const QString &CountryCode,
           const QString &CountryName, const QString &City, const QString &Tier,
           const float &LoadFactor, const bool Available)
      : id(Id), countryCode(CountryCode), countryName(CountryName), city(City),
        tier(Tier), loadFactor(LoadFactor), available(Available) {}

  Location(const QJsonObject &o) {
    id = o["id"].toString();
    countryCode = o["country_code"].toString().toLower();
    countryName = o["country_name"].toString();
    city = o["city"].toString();
    city = o["tier"].toString();
    loadFactor = o["load_factor"].toDouble();
    available = o["available"].toBool();
  }
};
