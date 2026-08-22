# Admin Password
Is not possible to overwrite it on code because there's no instrumentation. You have to login and change manually

First password is always:
user: admin
password: admin123

# Converting ebooks

Enter on an Ebook and click EDIT and a button will show

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

