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

### ios sync_certificates

```sh
[bundle exec] fastlane ios sync_certificates
```

Sync certificates and provisioning profiles for all targets

Requires --env to be set to 'freemium' or 'premium'

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

Requires --env to be set to 'freemium' or 'premium'

### ios update_metadata

```sh
[bundle exec] fastlane ios update_metadata
```

Update metadata in App Store Connect

Requires --env to be set to 'freemium' or 'premium'

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Submit a new beta build to TestFlight

Requires --env to be set to 'freemium' or 'premium'

### ios app_store

```sh
[bundle exec] fastlane ios app_store
```

Deploy a new freemium and premium version to the App Store

### ios apply_config

```sh
[bundle exec] fastlane ios apply_config
```

Apply app configuration to release a different version

Requires --env to be set to 'freemium' or 'premium'

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
