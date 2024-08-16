## Git organization

### Project creation

A new project is always created as a result of particular needs. Therefore, there should be some form of input specifications for it. 

In order to create a project, a proposal Pull Request to this repo with a proposal must be created. In the proposal, basic information about the project will be provided. A PR template, specific for this procedure, will be available.

Once the Pull Request (which should follow the rules that will be explained below) is approved, the project will be added to the organization. 


#### Naming 

Projects are named using kebab-case.

#### Maintainers

Projects belong usually to a [team](https://github.com/orgs/2060-io/teams). As a general rule, all team members have write access to them. However, not every member is a maintainer. During the project proposal phase, at least a maintainer should be assigned.

### Branches

Projects do have a long-lived, main branch where newest features are implemented. This branch is called _main_. 

This branch should be protected, in such a way that no direct commits or force pushes are allowed.

Every commit to main branch is supposed to contain an unstable but usable state, meaning by this that it should pass at least a minimal sanity test (it builds, contains appropriate formatting, passes unit tests, it is possible to deploy it to a test environment, etc.)

Besides main branch, we have two other branch types:

- **Feature branches**: usually created from main, these short-lived branches are meant to handle a new feature or fix that will be integrated into the origin branch. They are deleted as soon as this happens
- **Maintenance branches**: created when a new feature or fix must be integrated into a previously released line (e.g. 1.x when we are already working on 2.x). There is no need to create maintenance branch for every release, but only for those where a fix or feature is already scheduled. Later on, it can be reused for further minor releases if there is a need to do so

### Commit rules

In long-lived branches, commits follow [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) rules. In particular, we use [Angular convention](https://github.com/angular/angular/blob/22b96b9/CONTRIBUTING.md#-commit-message-guidelines) for the type definition and subject, body and footer writing guidelines.

It is not mandatory to follow these rules in feature branches. However, we encourage to use it, as in some cases it is useful: for instance, if we want to cherry-pick some commits from a PR that is closed prior to being merged.

#### Commit signature

When commiting, you should always use your real name and GitHub associated e-mail address (set them in `user.name` and `user.email` git config settings). This is important to make sure that all your activity is properly tracked in your GitHub profile.

Since we are usually contributing to Linux Foundation and other open source projects that require [Developer Certificate of Origin](https://developercertificate.org/), we encourage to sign-off every commit 

> Note: To add DCO signature, simply add the `-s` option to git commit command or use `Commit Staged (Signed off)` in VS Code's Commit options).

### Pull Request rules

The only way to commit into main branch is through a Pull Request (PR) that must be approved by another member of the team with right permissions.

Unless the introduced change is too obvious or it is detailed somewhere else, it is important in the description to briefly summarize the concepts/reasons behind the PR and, in case of new features, architecture details to facilitate the review. Screenshots and videos usually help.

PRs can be related to issues, although it is not mandatory (neither desirable) to create an issue in the project in order to create a PR. Either in PR description (by using the clause `Fixes #<issue reference>` or `Closes #<issue reference>)` or PR's `Development` field.

Try to keep PRs as small and focused as possible: we want PRs to be expedite and feature branches to be closed sooner than later, in order to avoid merge conflicts and to provide clear details about the changes introduced in the main branch.

PRs must be named after their main purpose using the aforementioned commit rules (e.g. 'feat: a new feature' or 'fix: an important bugfix'). When merging a Pull Request, all commits should be squashed into a single one whose message will be the same as PR's name, so it is good to have the good naming from the start. 

Once the PR is merged, the feature branch should be deleted.

### Release strategy

As explained before, main branch should be in a state where it can be built and used but not necessarily be ready for production. So each commit on main branch might be considered as a new pre-release version. It is therefore possible to trigger, upon each commit into main branch, a CD stage that deploys it into a development environment, or publish it into development channels.

When the code in _main_ is considered to have reached a state where it is ready for a further stage, a Release must be created:

- If the code is going to a testing stage (staging) before going into production, the release must be marked as 'pre-release'. The release and its associated tag should trigger its deployment into staging environment (or publishing into staging channel)
- If the code has either passed the staging step or its policy does not include such intermediate testing stage, the release and its associated tag should trigger its deployment into production

We use semantic versioning to name the releases (X.Y.Z), where versions are upgraded as follows:

- Major: changes are significant, and/or breaking API changes are introduced
- Minor: there are changes in features that do not represent a breaking API change
- Patch: no new features. Bugfix only (not introducing any breaking API change)

These rules have particular meaning once the project has reached an initial 'official' release (i.e. 1.0.0). When it has been just started, some pre-releases with naming 0.X.Y could be delivered. In such case, we expect minor for breaking/significant changes and patch for both minor updates and fixes.

### Feature and fix workflow

Whenever new features are developed, feature branches from current state of `main` branch are created. These branches are meant to be short-lived and deleted as soon as they get merged into `main`. Naming for such branches follow the pattern `feat/description-of-the-feature`. It is encouraged to prefix the description with the number of the issue that originates it (if any).

Same considerations as before apply also for fixes, whose branches follow the pattern `fix/description-of-the-fix`. However, there are some differences on the way they are integrated into codebase, especially when a release has been already done.

New features are always integrated into the mainline branch (`main`) and the same happens to the fixes. In case we want to backport a fix to a previously released version, we need to create a maintenance branch for it and cherry-pick the commits there.

For example, suppose the release 1.0.0 has been done and we already introduced breaking changes in `main`, so we are working on 2.0.0 pre-releases. During this time, a bug that affects also 1.0.0 is found and we want it to be fixed without waiting for 2.0.0 (or force users to upgrade). So the procedure is the following: 

- Create a `v1` maintenance branch from the commit tagged as `v1.0.0` (i.e. the one that produced the release)
- Create a fix branch from `main` to treat the issue, and merge it to `main` as well. 
- Perform a cherry-pick of that particular commit into `v1`
- Create a new release from new `v1` state and call it `v1.0.1` or `v1.1.0`, depending on the rules stated above

Note: there are some bugs that only affect previous versions (i.e. they are not present in `main` codebase). In such cases, it is fine to create the fix branch from maintenance branch (`v1` for this example).

![](./assets/branch-example-1.png)

```plantuml
@startuml
participant main as "main"
participant v1 as "v1.0"
participant f1 as "feat/1"
participant f2 as "feat/2"
participant f3 as "feat/3"
participant f4 as "fix/4"

main -> f1
main -> f2
f1 -> f1: feat: 1
main <- f1
note left
v1.0.0-dev.1 
end note
f2 -> f2: feat: 2
main <- f2
note left
v1.0.0-dev.2 
end note
main -> main: Release 1.0.0
note left 
v1.0.0
end note
main -> v1
main -> f3
f3 -> f3: feat: 3
main <- f3
note left 
v1.1.0-dev.1
end note
note over main, f4
Now a bug is found and we want to create a hotfix release for v1.0.x
end note
main -> f4
f4 -> f4: fix: 4
main <- f4
note left
v1.1.0-dev.2
end note

main --> v1: cherry-pick latest commit
v1 -> v1: Release 1.0.1
note left 
v1.0.1
end note


@enduml
```