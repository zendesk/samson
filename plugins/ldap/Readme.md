Login with LDAP

```
AUTH_LDAP=true
LDAP_TITLE= # eg. My LDAP Server}
LDAP_HOST=192.168.25.188
LDAP_PORT=389
LDAP_BASE='dc=domain,dc=com'
LDAP_UID=uid
LDAP_BINDDN=userldap
LDAP_PASSWORD=myldapsecret
```

### Use LDAP_UID as user.external_id.

The default is to use the Distinguished Name for users.external_id.  If your organization changes
any part of the DNs for any reason, this could cause any configured users to loose their current
configuration since it will be assumed to be a new user with a new external_id.  This feature
forces the value of `LDAP_UID` (set above), which is used to query the user in the LDAP, which
almost certainly is unique per user, to also be used for the external_id.  Note, this name must
also exist in the "extra" raw info:
https://github.com/omniauth/omniauth-ldap/blob/master/README.md
https://github.com/omniauth/omniauth-ldap/blob/master/lib/omniauth/strategies/ldap.rb#L17

```
USE_LDAP_UID_AS_EXTERNAL_ID=1
```
