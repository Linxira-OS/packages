# Calamares Packaging Notes

This recipe builds the official Calamares 3.3.14 release archive. The source
archive is pinned to the SHA-256 published with the upstream release and does
not use a CachyOS package, repository, or source fork.

Calamares is an installer framework. Linxira-specific module configuration,
branding, package manifests, and offline repository policy belong to the
Direct-Arch installer profile and are not compiled into this package.

The package carries one upstream-facing compatibility patch. Calamares 3.3.14
adds the removed `crc32c-intel` kernel module for Intel systems using Btrfs,
which makes current `mkinitcpio` fail. The patch leaves CRC32C implementation
selection to kernel module dependencies.
