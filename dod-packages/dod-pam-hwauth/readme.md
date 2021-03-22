
# DoD PAM Hardware Auth Library

This directory contains Rust code which builds a PAM module
for use in DoD operating systems.

# System design

When invoked by PAM to authenticate a user this module makes
the following decisions:

 - If the username is not `owner`, the __authentication fails__
 - Read public keys from `/etc/dod_authorized_owners` and all files within `/etc/dod_authorized_owners.d/`
 - If there are no public keys, the first hardware token inserted will be __granted access__ to the `owner` account and the key will be added to `/etc/dod_authorized_owners`.
 - If there are public keys, the first hardware token inserted will be queried for it's public key. If the hardware token public key is not in the list of authorized owners, __authentication fails__.
 - If the hardware token public key is in the list of authorized owners, the token will be challenged to prove identity. If the challenge succeeds, __access is granted__. If the challenge fails, __authentication fails__.


# Building


```bash
cargo build --release
# Builds dod-pam-hwauth/target/release/libdod_pam_hwauth.so
```


# Usage

Place `libdod_pam_hwauth.so` at `/lib/security/libdod_pam_hwauth.so`.

Write a config file named `/etc/pam.d/dod-hwauth` with the contents:

```
auth sufficient libdod_pam_hwauth.so
account sufficient libdod_pam_hwauth.so
```

Now all programs which query PAM for authentication will 
