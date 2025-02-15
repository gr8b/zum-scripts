## Collection of scripts for module development

### rename.sh

Useful to make fast prototype from build in widget.

Copy widget directory to modules directory:
```sh
cp -R /zabbix/widgest/actionlog /zabbix/modules/my-actionlog
```

Run script to modify copy of widget to work along side with build in one.
```sh
./rename.sh --dir /zabbix/modules/my-actionlog
```

Now can go to Administration and enable copied widget.
