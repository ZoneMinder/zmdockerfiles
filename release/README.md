# ZoneMinder Release Dockerfiles
This folder contains Docker files used for running the latest ZoneMinder release.
If you are looking to run the latest code from the master branch, see the [development](https://github.com/ZoneMinder/zmdockerfiles/tree/master/development) folder instead.

Contributions are welcome, but please follow these simple guidelines:

- Only one Dockerfile per distro
- Keep each Dockerfile sorted by distro
- Use our [entrypoint script](https://github.com/ZoneMinder/zmdockerfiles/blob/master/utils/entrypoint.sh) as the entrypoint in your Dockerfile. It is intended to work with most Linux distros and will take care of starting mysql, apache, then zoneminder.
- Each Dockerfile should be self sufficient. It should grab the ZoneMinder project, and any other other requried files, from github or other online resource, rather than expect files to pre-exist on the filesystem.
- Avoid building ZoneMinder. Instead, install ZoneMinder from a package, using a third party repo if necessary.
