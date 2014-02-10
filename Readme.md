# send_ios_notifs.sh #

## What is it? ##

`send_ios_notifs.sh` is a small bash script that can send push notifications to iOS devices. This script is intended for debug purpose only and should **not** be used in production.

Usage is at the end of this Readme.

Do not hesitate to report any bugs you encounter. There is no warranty whatsoever on using this script. Your computer might as well blow if you use this script; I won't take any responsability.

## What does it do? ##

The script can currently send a custom message to an iOS device. Only the `alert` key of the `aps` dictionary can be customized with the current version of the script.

## What does it **not** do? ##

This script can't generate Apple Push tokens. You must get them from an iOS device directly, using Apple's SDK for Push Notification. See the documentation for more informations.

## Usage ##

```
send_notifs.sh sandbox|prod tokens_file message
```

  * `sandbox|prod`: Whether to connect to the sandbox or production server to send the push.
  * `tokens_file`: A file containing base64 encoded iOS devices tokens. One token per line. No comments possible.
  * `message`: The message sent to the devices.

The certificate file to be used to connect to the Apple Push servers must be in `certificates/apple_push_certificate.pem` when in production mode, in `certificates/apple_push_certificate_sandbox.pem` when in sandbox mode.

You can password protect your certificates. The password must be in `certificates/apple_push_certificate.pass` (or `certificates/apple_push_certificate_sandbox.pass`). **Warning**: The handling of special characters in the password is far less than ideal (double quotes are known not to work, the rest is untested).
