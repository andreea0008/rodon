#pragma once

class SparkleUpdater {
public:
  static SparkleUpdater *instance();
  void checkForUpdates();

private:
  SparkleUpdater();
  ~SparkleUpdater();
  void *m_controller;
};