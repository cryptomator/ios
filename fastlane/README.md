fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios certificates

```sh
[bundle exec] fastlane ios certificates
```

Sync certificates and provisioning profiles for all targets

### ios create_screenshots

```sh
[bundle exec] fastlane ios create_screenshots
```

Create screenshots in every language with every device

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload screenshots to App Store Connect

### ios update_metadata

```sh
[bundle exec] fastlane ios update_metadata
```

Update metadata in App Store Connect

### ios test

```sh
[bundle exec] fastlane ios test
```

Runs all the tests

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Submit a new beta build to TestFlight

### ios app_store

```sh
[bundle exec] fastlane ios app_store
```

Deploy a new version to the App Store

### ios update_app

```sh
[bundle exec] fastlane ios update_app
```

Update app configuration to release a different version

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
