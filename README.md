# openwrt-overlay-separator

This script is not yet completed.

CURRENTLY WORK IN PROGRESS! Use for test only!

Contributions are welcome.

## Target
On some devices which have easy direct access to its storage devices like x86 and single board computers, it is better to have a separate partition for /overlay when running on squashfs /rom. Because they usually don’t have limitations for storage space. This can help combine the ease of squashfs and easy to manage.

## References

This script include some parts from OpenWrt docs which is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.en).
- https://openwrt.org/docs/guide-user/advanced/expand_root
- https://openwrt.org/docs/techref/init.detail.cc#life_and_death_of_a_chaos_calmer_system