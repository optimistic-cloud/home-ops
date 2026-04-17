https://github.com/lldap/lldap?tab=readme-ov-file



# This command connects to your lldap server as the admin user and performs a search starting from the root of your LDAP directory (dc=optimistic,dc=cloud), returning all entries visible to the admin.

```
docker run -it --rm --network lldap_default jefftadashi/ldapsearch -H ldap://lldap:3890 -D "uid=admin,ou=people,dc=optimistic,dc=cloud" -W -b "dc=optimistic,dc=cloud"
```


# to list all users in ldap
```
docker run -it --rm --network lldap_default jefftadashi/ldapsearch \
  -H ldap://lldap:3890 \
  -D "uid=admin,ou=people,dc=optimistic,dc=cloud" \
  -W \
  -b "dc=optimistic,dc=cloud" \
  "(objectClass=person)"
```

# to list all groups in ldap
```
docker run -it --rm --network lldap_default jefftadashi/ldapsearch \
  -H ldap://lldap:3890 \
  -D "uid=admin,ou=people,dc=optimistic,dc=cloud" \
  -W \
  -b "dc=optimistic,dc=cloud" \
  "(objectClass=groupOfNames)"
```

# list all users in the group dav
docker run -it --rm --network lldap_default jefftadashi/ldapsearch \
  -H ldap://lldap:3890 \
  -D "uid=admin,ou=people,dc=optimistic,dc=cloud" \
  -W \
  -b "dc=optimistic,dc=cloud" \
  "(memberOf=cn=dav,ou=groups,dc=optimistic,dc=cloud)"

# 
docker run -it --rm --network lldap_default jefftadashi/ldapsearch \
  -H ldap://lldap:3890 \
  -D "cn=max,ou=people,dc=optimistic,dc=cloud" \
  -W \
  -b "cn=max,ou=people,dc=optimistic,dc=cloud" \
  "(objectClass=*)" \
  cn mail


ldapadd -H ldap://localhost:3890 -D "uid=admin,ou=people,dc=tryrocket,dc=cloud" -W -f family.ldif

docker run -it --rm --network lldap_default jefftadashi/ldapadd \
  -H ldap://lldap:3890 \
  -D "uid=admin,ou=people,dc=optimistic,dc=cloud" \
  -W \
  -f family.ldif

## Systemd


### renew certificate

- systemctl --user start lldap-certbot-renew.service
- journalctl --user -xeu lldap-certbot-renew.service