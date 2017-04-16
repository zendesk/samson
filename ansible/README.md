Using Ansible to create the Samson VPC.
---

  * First install ansible (latest as possible).
  * export your aws credentials like so:

```
export AWS_ACCESS_KEY=<youraccessid> ; export AWS_SECRET_KEY=<yoursecret>
```

  * You will need to decrypt this secret from the toolbox repo.

```
gpg --decrypt ~/yourpathto/toolbox/gpg/assets/deploy-keys/samson_ansible_deploy.asc
```

  * To build the VPC run this command:

```
ansible-playbook -i hosts/host.ini plays/build_vpc.yml -e @group_vars/production.yml --ask-vault-pass -e @secrets/production.yml
```

  * You will be asked for a password, use the one you have just decrypted from the toolbox.
  * This should build a vpc or confirm the VPC is already built and running.

TODO:
---
  * Ansible is not building the elasticcache and RDS instances in the VPC but in the default one, find out why
  * Hopefully there will be a solution to having multiple ansible-vault files so we can pass in our own aws credentials 
    without having to export them.
  * Add users
  * Validate the ASG
  * Deploy code.
