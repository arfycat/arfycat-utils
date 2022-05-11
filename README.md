Utilities used by Arfycat hosts.

# Installation
## Debian

Tested on Debian and Ubuntu

```
echo "deb https://arfycat.com/pkg/Ubuntu /" > /etc/apt/sources.list.d/arfycat.list
chmod 644 /etc/apt/sources.list.d/arfycat.list

curl https://arfycat.com/pkg/pkg@arfycat.com.pub | tee /etc/apt/trusted.gpg.d/arfycat.asc
chmod 644 /etc/apt/trusted.gpg.d/arfycat.asc

apt update
apt install arfycat-utils
```
