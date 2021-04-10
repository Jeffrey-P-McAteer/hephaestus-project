
# The Hephaestus Project

This code repository contains:

 - An operating system build script derived from [Arch Linux](https://archlinux.org/)
    - Execute `builder.sh` from any linux machine to create the OS and deploy to an external hard drive

 - Code for packages fulfilling government OS requirements
    - See [`packages/readme.md`](packages/readme.md)
    - The Hephaestus project adds hardware authentication, universal encrypted comms,
      a passive threat reporting daemon, and encrypted containers as part of the `base` group of packages.

 - Documentation and deployment scripts for a single server which can be used to:
    - deploy Hephaestus OS
    - host your organization's software packages
    - track software package issues
    - perform 100% automated software package tests and builds
    - provide universal encrypted comms
    - and report on your organization's observed passive digital threats

# Goals

The Hephaestus project aims to make every organization's software aquisition,
integration, deployment, and continued maintenance as boring and efficient as possible.

This is accomplished by forcing every component of the Hephaestus project to be 100% automated,
which opens the door to accomplish more difficult quality controls such as 100% test coverage
and enforcing that 100% of tests pass before any component is deployed.

For end users this means they are given root access to hardware they own, reducing administration costs
and enforcing policy in an automated fasion at the package level rather than through manual paperwork,
in a similar way to how Apple maintains control over their App Store ecosystem.

For developers this means new software changes may be deployed within the hour, with the caveat that
100% of tests pass and the expectation that the organization will use a package system containing
`testing` / `stable` / `deprecated` repositories, of which the newest changes stay in `testing` for at least a week
before being promoted to `stable` if no issues are opened.

For administrators this means fewer manual code reviews, zero IT time spent installing software for end users,
a new source of business metrics such as "issues closed per day" and "external digital threats detected",
and the creation of 100% automated policy enforcement by means of the package server you own and operate;
your end users will only be able to use software you put in the package server, and your CI pipeline means
you can apply patches to modify the behavior of upstream software before building it and putting it in the package server.

As long as your organization can make the decision to never deploy code which fails tests,
every goal of the Hephaestus project can be accomplished.






