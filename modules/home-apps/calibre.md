# Admin Password
Is not possible to overwrite it on code because there's no instrumentation. You have to login and change manually

First password is always:
user: admin
password: admin123

# Converting ebooks

Enter on an Ebook and click EDIT and a button will show

Some books can only be converted by adding then to ingest folder using Plugins. Check below

# Plugins

I downloaded from: 

**Kindle:** https://github.com/noDRM/DeDRM_tools/releases/download/v10.0.3/DeDRM_tools_10.0.3.zip. I extracted before puting on calibre_plugins

**Kobo:** https://github.com/Leseratte10/acsm-calibre-plugin/releases/download/v0.0.16/DeACSM_0.0.16.zip


## Kindle
Go to Amazon > Devices > Copy Serial Number
Once that is in you can put a book on ingest folder and it will already DeDRM,

## Kobo
Once you download a book from Kobo it will come with .acsm extension. You can drop it in the ingest and it will convert for you

To configure authentication:
I had to install Calibre + the plugin manually in a desktop app. 
On Calibre > Preferences > Plugins > Click on DeACSM > Customize:
1. Authenticate with your Byte Book Account
2. Go to app settings and retrieve the authentication file. It's on `~/Library/Preferences/calibre/plugins/dedrm.json`. That file I put in Vault which is synced with calibre.
3. Via calibre app, export Account Activation Data. You will receive 3 files: device.xml, activation.xml and devicesalt
For devicesalt is a binary so you need to do `base64 -i devicesalt | pbcopy` and copy to Vault

That was a hell of a work!


# First Import

This is one-off job.

Scale to 0 so there's no corruption:

```
kubectl -n calibre scale deployment calibre --replicas=0
```

I ran as a kubernetes job:

```
sed \
  -e "s|:><VERSION>|:v4.0.6|" \
  -e "s|<YOUR_NFS_SERVER_IP>|ADD_IP|g" \
  -e "s|<NFS_PATH>|ADD-PATH|g" \
  -e "s|<NFS_USER_ID>|NFS_USER|g" \
  -e "s|<NFS_GROUP_ID>|NFS_GROUP|g" \
  modules/home-apps/calibre-import-job.yml > calibre-import-rendered.yaml
```

kubectl -n calibre apply -f calibre-import-rendered.yml

