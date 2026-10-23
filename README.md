# libssh-apple

A description of this package.

## Releasing xcframeworks

CI builds the xcframeworks on pull requests (except Markdown-only changes) and manual runs. It uploads the ZIPs, `checksums.txt` and `release.md` in the `xcframeworks` artifact. The build summary lists each slice and its architectures.

To release from this repository, push a `v*` tag, then wait for the "Publishing release" job. It creates a release with the generated notes, or adds the assets to an existing release while keeping its notes. Uploads fail if an asset already exists; published files are never overwritten. Only the release job has write permission.

Update each consuming `binaryTarget` URL and checksum with the new release and the values in `checksums.txt`.
