# XeeonOS applications

`.xapp` applications for [XeeonOS](https://github.com/ivansollazzo/xeeonos):
an application is a directory `Name.xapp` with its files and a manifest
(`xapp.conf`). Copy it into `~/Applications` (or `xctl app install`) and it
appears in the menu; delete it and it is gone.

This repository holds the recipes that make them from upstream builds
(Firefox first) and their tests. Support for `.xapp` itself (`xctl app`, the
monitor of `/var/lib/xapps`) is part of the system, in the main repository.

Work in progress: the Firefox recipe moves here from the main repository.

Branch `experimental`: development, as in the main repository.
