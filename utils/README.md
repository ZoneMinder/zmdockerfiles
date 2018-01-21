# ZoneMinder Docker Entrypoint Script
Use this script as the entrypoint in your Dockerfile. 

Entrypoint.sh looks in common places in the container filesystem for the files and executables it needs to run. 
It should be compatible with most major Linux distributions.

If the Linux distro you are using stores a critical component in a folder unknown to the script, the script will
fail with an appropriate message, indicating what it could not find. If that is the case, it is fairly straight forward
to teach the script to look in additional folders for said critical component. Refer to the initialize subroutine inside the script.
