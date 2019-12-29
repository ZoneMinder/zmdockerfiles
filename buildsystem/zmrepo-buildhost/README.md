## ZMRepo Remote Buildhost Configuration

The instructions and files contained in this folder allow any third party to contribute builds to ZMRepo that otherwise would not be available.

PREREQUISITES
-------------

Before a new machine can be added as a build host, the following must be done first:
- [Contact the Development Team](https://github.com/ZoneMinder/zoneminder#contacting-the-development-team) and let us know the desired Operating System, Distribution, and Architecture e.g. CentOS 8 on aarch64.
- Docker must be installed and working, using a non-root user account
- A tagged image must exist in any dockerhub repo, named with this format: OS-Distro-Arch. Arch is only required for non-AMD64 builds. See the [packpack dockerhub repo](https://hub.docker.com/r/packpack/packpack/tags) for an example.
- The tagged image must be verified to work with packpack. See [these instructions](https://zoneminder.readthedocs.io/en/stable/installationguide/packpack.html).
- Send us an rsa key of the machine in question

INSTALLATION STEPS
------------------
These steps assume you have cloned zmdockerfliles to your local drive and are relative to the folder `buildsystem/zmrepo-buildhost`.

**Step 1:** Open `synczmrepo.sh` with your favorite text editor:

    - Set the paths for HEAD and GIT_HOME to something your user account can write to.
    - All the commands used in the script are shown and their path. Verify these commands exist on your system and the paths are correct. For example, you may need to install `jq`.
    - Scroll down to the portion of the script labelled "STEP 2". Add, remove, or edit the lines that start the packpack build to suite.

**Step 2:** Copy `synczmrepo.sh` to your local bin folder and make it executable

    sudo cp synczmrepo.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/synczmrepo.sh

**Step 3:** Open `synczmrepo.service` with your favorite text editor and change the `User=youraccount` line to match the name of your user account.

**Step 4:** Copy `synczmrepo.service` to your local systemd service folder

    sudo cp synczmrepo.service /etc/systemd/system/

**Step 5:** Enable the synczmrepo service to start automatically then start the service.

    sudo systemctl enable synczmrepo.service
    sudo systemctl start synczmrepo.service
    
**Step 6:** Verify the service is running.

    systemctl status synczmrepo.service
    
**Step 7:** Optionally monitor the progress of the service.

    journalctl -u synczmrepo -f
