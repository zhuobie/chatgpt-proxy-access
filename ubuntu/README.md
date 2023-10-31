# Introduction

Shell scripts that can assist in deploying SoftEther VPN server and client.

- server_deploy: Similar to the script above, but lacks the WARP and Tinyproxy services.

- client_deploy: Installs only the SoftEther client, users need to specify other server addresses themselves, with the default being the local machine.

# Usage

System requirements: Ubuntu 22.04(jammy)

- ./server_deploy.sh status | install | uninstall | enable | disable

- ./client_deploy.sh status | install | uninstall | enable | disable

If necessary, you can modify the global variables in the shell script to make it meet your requirements.