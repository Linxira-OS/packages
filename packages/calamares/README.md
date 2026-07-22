# Calamares Packaging Notes

This recipe builds the official Calamares 3.3.14 release archive. The source
archive is pinned to the SHA-256 published with the upstream release and does
not use a CachyOS package, repository, or source fork.

Calamares is an installer framework. This package carries Linxira's native
C++/Qt Catalog v3 software-selection view module and its module configuration.
Branding, package manifests, and offline repository policy remain in the
Direct-Arch installer profile.

The package also carries an upstream-facing compatibility patch. Calamares 3.3.14
adds the removed `crc32c-intel` kernel module for Intel systems using Btrfs,
which makes current `mkinitcpio` fail. The patch leaves CRC32C implementation
selection to kernel module dependencies.
