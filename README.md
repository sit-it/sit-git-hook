# Superseded by [sit-inbox](https://git.sit.fyi/sit-inbox)

You can still use it for a little while, however, once sit-inbox will get support for
https/ssh git endpoints, there will be no point in this hook.

---

# SIT Git Hook

One of the important problems when distributing
issues over an SCM (such as Git) is that the
workflow is quite painful unless you have direct
push rights to the repo.

So, in terms of Git/GitHub setup, this means that
one has not only to prepare a branch with their
submission, but also send a pull request, wait
for one of the mainters to merge it in, slowing
down the interaction significantly.

This hook is aimed to solved this problem.

The hook will validate that a new branch
is being created and whatever is being pushed
is only new records -- not anything outside of
issues, not overwriting any existing files in records,
not adding new files to existing records.

If that validation passes, the second hook
will push the change out to the master repo.

## Configuration

Before putting these hooks into a repo,
one must edit them to specify their master repository
in `MASTER_REPO` variable in both hooks.

## Deployment with Gitolite

Firstly, you need to ensure that repo-specific hooks are enabled.
Add this to your gitolite rc-file:

```perl
$RC{LOCAL_CODE} = "$rc{GL_ADMIN_BASE}/local";
$RC{GIT_CONFIG_KEYS} = "sit\..*";
push @{$RC{ENABLE}}, 'repo-specific-hooks';
```

Secondly, you need to generate a new SSH keypair. The private key
is to be shared to those who should be able to push
their records. The public one needs to be copied to `gitolite-admin/keydir`.

Then, the hook has to be copied into `gitolite-admin/local/hooks/repo-specific`
and configuration updated:

```
repo project-inbox
    RW      = sit-inbox
    RW+     = @admin
    config sit.target = https://USER:TOKEN@github.com/OWNER/REPO.git
    # config sit.targetbranch = master
    option hook.pre-receive = <pre-receive-file-name> 
```

