#!/bin/sh
set -eu

# OpenWrt ImageBuilder - ASUS RT-N56U
make image PROFILE="asus_rt-n56u" PACKAGES="\
  base-files busybox ca-bundle dnsmasq dropbear firewall4 fstools kmod-gpio-button-hotplug \
  kmod-leds-gpio kmod-nft-offload kmod-rt2800-pci kmod-rt2800-soc libc libgcc libustream-wolfssl logd \
  mtd netifd nftables odhcp6c odhcpd-ipv6only opkg ppp ppp-mod-pppoe \
  procd procd-seccomp swconfig uci uclient-fetch urandom-seed urngd wpad-basic-wolfssl \
  kmod-usb-ohci kmod-usb2 luci 6in4 6rd 6to4 map ds-lite \
  ipip ppp-mod-pptp luci-proto-ipv6 luci-proto-ppp luci-proto-ipip luci-proto-wireguard luci-i18n-base-ar luci-i18n-base-bg \
  luci-i18n-base-bn luci-i18n-base-ca luci-i18n-base-cs luci-i18n-base-da luci-i18n-base-de luci-i18n-base-el luci-i18n-base-en luci-i18n-base-es \
  luci-i18n-base-fi luci-i18n-base-fr luci-i18n-base-he luci-i18n-base-hi luci-i18n-base-hu luci-i18n-base-it luci-i18n-base-ja luci-i18n-base-ko \
  luci-i18n-base-mr luci-i18n-base-ms luci-i18n-base-nl luci-i18n-base-no luci-i18n-base-pl luci-i18n-base-pt-br luci-i18n-base-pt luci-i18n-base-ro \
  luci-i18n-base-ru luci-i18n-base-sk luci-i18n-base-sv luci-i18n-base-tr luci-i18n-base-uk luci-i18n-base-vi luci-i18n-base-zh-cn luci-i18n-base-zh-tw \
  block-mount kmod-fs-ext4 kmod-fs-f2fs kmod-fs-msdos kmod-fs-ntfs kmod-fs-vfat ntfs-3g ntfs-3g-utils \
  dosfstools e2fsprogs dumpe2fs f2fs-tools f2fsck tune2fs resize2fs cfdisk \
  fdisk sfdisk cgdisk gdisk sgdisk hfsfsck mkhfs kmod-fs-hfsplus \
  kmod-fs-hfs luci-app-firewall luci-i18n-firewall-ar luci-i18n-firewall-bg luci-i18n-firewall-bn luci-i18n-firewall-ca luci-i18n-firewall-cs luci-i18n-firewall-da \
  luci-i18n-firewall-de luci-i18n-firewall-el luci-i18n-firewall-en luci-i18n-firewall-es luci-i18n-firewall-fi luci-i18n-firewall-fr luci-i18n-firewall-he luci-i18n-firewall-hi \
  luci-i18n-firewall-hu luci-i18n-firewall-it luci-i18n-firewall-ja luci-i18n-firewall-ko luci-i18n-firewall-mr luci-i18n-firewall-ms luci-i18n-firewall-nl luci-i18n-firewall-no \
  luci-i18n-firewall-pl luci-i18n-firewall-pt-br luci-i18n-firewall-pt luci-i18n-firewall-ro luci-i18n-firewall-ru luci-i18n-firewall-sk luci-i18n-firewall-sv luci-i18n-firewall-tr \
  luci-i18n-firewall-uk luci-i18n-firewall-vi luci-i18n-firewall-zh-cn luci-i18n-firewall-zh-tw luci-app-opkg luci-i18n-opkg-ar luci-i18n-opkg-bg luci-i18n-opkg-bn \
  luci-i18n-opkg-ca luci-i18n-opkg-cs luci-i18n-opkg-da luci-i18n-opkg-de luci-i18n-opkg-el luci-i18n-opkg-en luci-i18n-opkg-es luci-i18n-opkg-fi \
  luci-i18n-opkg-fr luci-i18n-opkg-he luci-i18n-opkg-hi luci-i18n-opkg-hu luci-i18n-opkg-it luci-i18n-opkg-ja luci-i18n-opkg-ko luci-i18n-opkg-mr \
  luci-i18n-opkg-ms luci-i18n-opkg-no luci-i18n-opkg-pl luci-i18n-opkg-pt-br luci-i18n-opkg-pt luci-i18n-opkg-ro luci-i18n-opkg-ru luci-i18n-opkg-sk \
  luci-i18n-opkg-sv luci-i18n-opkg-tr luci-i18n-opkg-uk luci-i18n-opkg-vi luci-i18n-opkg-zh-cn luci-i18n-opkg-zh-tw luci-app-wireguard luci-i18n-wireguard-ar \
  luci-i18n-wireguard-bg luci-i18n-wireguard-bn luci-i18n-wireguard-ca luci-i18n-wireguard-cs luci-i18n-wireguard-da luci-i18n-wireguard-de luci-i18n-wireguard-el luci-i18n-wireguard-en \
  luci-i18n-wireguard-es luci-i18n-wireguard-fi luci-i18n-wireguard-fr luci-i18n-wireguard-he luci-i18n-wireguard-hi luci-i18n-wireguard-hu luci-i18n-wireguard-it luci-i18n-wireguard-ja \
  luci-i18n-wireguard-ko luci-i18n-wireguard-mr luci-i18n-wireguard-ms luci-i18n-wireguard-no luci-i18n-wireguard-pl luci-i18n-wireguard-pt-br luci-i18n-wireguard-pt luci-i18n-wireguard-ro \
  luci-i18n-wireguard-ru luci-i18n-wireguard-sk luci-i18n-wireguard-sv luci-i18n-wireguard-tr luci-i18n-wireguard-uk luci-i18n-wireguard-vi luci-i18n-wireguard-zh-cn luci-i18n-wireguard-zh-tw \
  luci-app-uhttpd luci-i18n-uhttpd-ar luci-i18n-uhttpd-bg luci-i18n-uhttpd-bn luci-i18n-uhttpd-ca luci-i18n-uhttpd-cs luci-i18n-uhttpd-da luci-i18n-uhttpd-de \
  luci-i18n-uhttpd-el luci-i18n-uhttpd-en luci-i18n-uhttpd-es luci-i18n-uhttpd-fi luci-i18n-uhttpd-fr luci-i18n-uhttpd-he luci-i18n-uhttpd-hi luci-i18n-uhttpd-hu \
  luci-i18n-uhttpd-it luci-i18n-uhttpd-ja luci-i18n-uhttpd-ko luci-i18n-uhttpd-mr luci-i18n-uhttpd-ms luci-i18n-uhttpd-no luci-i18n-uhttpd-pl luci-i18n-uhttpd-pt-br \
  luci-i18n-uhttpd-pt luci-i18n-uhttpd-ro luci-i18n-uhttpd-ru luci-i18n-uhttpd-sk luci-i18n-uhttpd-sv luci-i18n-uhttpd-tr luci-i18n-uhttpd-uk luci-i18n-uhttpd-vi \
  luci-i18n-uhttpd-zh-cn luci-i18n-uhttpd-zh-tw luci-app-upnp miniupnpd-nftables luci-i18n-upnp-ar luci-i18n-upnp-bg luci-i18n-upnp-bn luci-i18n-upnp-ca \
  luci-i18n-upnp-cs luci-i18n-upnp-da luci-i18n-upnp-de luci-i18n-upnp-el luci-i18n-upnp-en luci-i18n-upnp-es luci-i18n-upnp-fi luci-i18n-upnp-fr \
  luci-i18n-upnp-he luci-i18n-upnp-hi luci-i18n-upnp-hu luci-i18n-upnp-it luci-i18n-upnp-ja luci-i18n-upnp-ko luci-i18n-upnp-mr luci-i18n-upnp-ms \
  luci-i18n-upnp-no luci-i18n-upnp-pl luci-i18n-upnp-pt-br luci-i18n-upnp-pt luci-i18n-upnp-ro luci-i18n-upnp-ru luci-i18n-upnp-sk luci-i18n-upnp-sv \
  luci-i18n-upnp-tr luci-i18n-upnp-uk luci-i18n-upnp-vi luci-i18n-upnp-zh-cn luci-i18n-upnp-zh-tw luci-app-ddns luci-i18n-ddns-ar luci-i18n-ddns-bg \
  luci-i18n-ddns-bn luci-i18n-ddns-ca luci-i18n-ddns-cs luci-i18n-ddns-da luci-i18n-ddns-de luci-i18n-ddns-el luci-i18n-ddns-en luci-i18n-ddns-es \
  luci-i18n-ddns-fi luci-i18n-ddns-fr luci-i18n-ddns-he luci-i18n-ddns-hi luci-i18n-ddns-hu luci-i18n-ddns-it luci-i18n-ddns-ja luci-i18n-ddns-ko \
  luci-i18n-ddns-mr luci-i18n-ddns-ms luci-i18n-ddns-no luci-i18n-ddns-pl luci-i18n-ddns-pt-br luci-i18n-ddns-pt luci-i18n-ddns-ro luci-i18n-ddns-ru \
  luci-i18n-ddns-sk luci-i18n-ddns-sv luci-i18n-ddns-tr luci-i18n-ddns-uk luci-i18n-ddns-vi luci-i18n-ddns-zh-cn luci-i18n-ddns-zh-tw ddns-scripts \
  ddns-scripts-cloudflare ddns-scripts-cnkuai ddns-scripts-digitalocean ddns-scripts-dnspod ddns-scripts-freedns ddns-scripts-gandi ddns-scripts-godaddy ddns-scripts-noip \
  ddns-scripts-ns1 ddns-scripts-nsupdate ddns-scripts-one ddns-scripts-pdns ddns-scripts-route53 ddns-scripts-services ddns-scripts-transip luci-app-hd-idle \
  luci-i18n-hd-idle-ca luci-i18n-hd-idle-cs luci-i18n-hd-idle-de luci-i18n-hd-idle-el luci-i18n-hd-idle-en luci-i18n-hd-idle-es luci-i18n-hd-idle-fr luci-i18n-hd-idle-he \
  luci-i18n-hd-idle-hu luci-i18n-hd-idle-it luci-i18n-hd-idle-ja luci-i18n-hd-idle-ms luci-i18n-hd-idle-no luci-i18n-hd-idle-pl luci-i18n-hd-idle-pt-br luci-i18n-hd-idle-pt \
  luci-i18n-hd-idle-ro luci-i18n-hd-idle-ru luci-i18n-hd-idle-sk luci-i18n-hd-idle-sv luci-i18n-hd-idle-tr luci-i18n-hd-idle-uk luci-i18n-hd-idle-vi luci-i18n-hd-idle-zh-cn \
  luci-i18n-hd-idle-zh-tw"
