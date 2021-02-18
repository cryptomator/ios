# Cryptomator for iOS

## Building

### Create Secrets

If you are building with Xcode, create a `.cloud-access-secrets.sh` file in the root directory. Its contents should look something like this:

```sh
#!/bin/sh
export GOOGLE_DRIVE_CLIENT_ID=...
export GOOGLE_DRIVE_REDIRECT_URL=...
export DROPBOX_APP_KEY=...
```

And then run `./create-cloud-access-secrets-file.sh` once. Of course, if you change the secrets, you have to run that script again.

If you are building via a CI system, set these secret environment variables accordingly.

#### Integration Testing

If you are running integration tests, you have to set those secrets as well. The file is called `.integration-test-secrets.sh`, also put it in the root directory. Contents are:

```sh
#!/bin/sh
export GOOGLE_DRIVE_REFRESH_TOKEN=...
export DROPBOX_ACCESS_TOKEN=...
export WEBDAV_BASE_URL=...
export WEBDAV_USERNAME=...
export WEBDAV_PASSWORD=...
```

## Contributing

Install [SwiftFormat](https://github.com/nicklockwood/SwiftFormat/) if you haven't already.

Please make sure that your code is correctly formatted. The easiest way to do that is to set up a pre-commit hook. Create a file at `.git/hooks/pre-commit` with this content:

```sh
./Scripts/process.sh --fail-on-errors
failed=$?
exit $failed
```

You may have to make the scripts executable:

```sh
chmod +x Scripts/process.sh
chmod +x .git/hooks/pre-commit
```
