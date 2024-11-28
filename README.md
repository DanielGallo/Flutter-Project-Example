# Flutter Project Example

A sample Flutter app based on [this example](https://github.com/flutter/samples/tree/main/testing_app).

This version of the app is configured to build in TeamCity Pipelines using the 
corresponding [`.teamcity.yml`](.teamcity.yml) file.

A Fastlane configuration file has been added in [`ios/fastlane/Fastfile`](ios/fastlane/Fastfile) to apply various 
settings to the Xcode project during build time and increment the iOS build version number. A signed version of the 
iOS app is then generated by the macOS agents in TeamCity Pipelines.

Since Flutter does not provide a test reporter for TeamCity out of the box, tests are executed via 
the [`ci/run_tests.dart`](ci/run_tests.dart) script. This script runs the tests in a child process using Flutter's `json` 
reporter, parses the results, and emits TeamCity service messages.