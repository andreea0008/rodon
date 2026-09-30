#import "SparkleUpdater.h"
#import <Sparkle/Sparkle.h>

SparkleUpdater *SparkleUpdater::instance() {
  static SparkleUpdater s;
  return &s;
}

SparkleUpdater::SparkleUpdater() {
  SPUStandardUpdaterController *controller =
      [[SPUStandardUpdaterController alloc] initWithStartingUpdater:YES
                                                    updaterDelegate:nil
                                                 userDriverDelegate:nil];
  m_controller = (__bridge_retained void *)controller;
}

SparkleUpdater::~SparkleUpdater() {
  if (m_controller) {
    CFRelease(m_controller);
  }
}

void SparkleUpdater::checkForUpdates() {
  SPUStandardUpdaterController *controller =
      (__bridge SPUStandardUpdaterController *)m_controller;
  [controller checkForUpdates:nil];
}