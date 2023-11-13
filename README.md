# Introduction

Shell scripts that can assist in deploying SoftEther VPN server and client.

- chatgpt_proxy_access.sh: Users can purchase VPS to resolve issues with accessing chat.openai.com in certain areas.

# Usage

System requirements: Debian 12(bookworm)

- ./chatgpt_proxy_access.sh status | install | uninstall | enable | disable

If necessary, you can modify the global variables in the shell script to make it meet your requirements.

After deploying, you can access chat.openai.com by the following steps: 

1. Install Softether VPN Client on your computer.

2. Configure Softether VPN Client to use the server you just deployed.

3. Connect to Softether VPN Client.

4. Use proxy 192.168.50.30:8888 in your browser.