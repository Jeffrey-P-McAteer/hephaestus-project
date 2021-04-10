
# Hephaestus Packages

This directory contains new software which separates Hephaestus OS from
general-purpose operating systems, specifically:

 - `dod-pam-hwauth`
     - Provides hardware authentication to the special `owner` account. This account has different semantics than
       most OS accounts; anyone with an authorized hardware token may gain access to this account.
       The authorization of the `owner` account is expected to match the authorization of the physical hardware identity-for-identity, and
       only existing owners may modify the ownership of the OS.
       In the abscence of any authorized owner information, the first inserted hardware token will be trusted.

 - `dod-crypt-nspawn`
     - Provides a wrapper around `systemd-nspawn` which encrypts the container's filesystem while it is not running. Containers are expected to
       be run by the `owner` account, but the people with access to the `owner` account do not need to be the people who can decrypt the container's filesystem.
     - Just like `dod-pam-hwauth`, this encryption relies on hardware tokens to decrypt data. No passwords are used.

 - `dod-kde-theme`
     - This package provides a KDE theme for Hephaestus machines to use. It should have the same decorum as the rest of DoD emblems, logos, and seals in use by the DoD and supporting agencies.

 - `dod-wireguard`
     - A port of wireguard which only uses hardware tokens for authorization. A management program will also be provided, such
       that users can list several VPN configurations and quickly select any number to connect to using their hardware ID.

 - `dod-autolock`
     - Small program which polls for hardware tokens; when the last hardware token used in a machine is removed this will trigger a screen lock.

 - `dod-encrypted-comm-ring`
     - Both a server and client, this program is designed to route messages between any two clients over a mesh of servers. The design is such that
       clients do not need to both be connected to the same server, but if a route exists between them messages will go pass
       as `client A -> server A -> server B -> client B`. Messages are timestamp authenticated and encrypted, so this can be thought of
       as a radio system where the only data needed to deliver a message is the recipient's public key.
     - Clients will have the ability to execute programs which parse incoming messages and take actions based on content; this will be a very powerful
       automation tool. DoD-ECR does not aim to do more than act as a delivery system to power these automated systems so as to avoid scope creep.

 - `dod-passive-threat-detector`
     - DoD-PTD will run eBPF programs in the kernel which will log events like port scans and suspicious network behavior. These logs can
       be configured to appear as notifications to the user to warn them of people on their network which may pose a threat to their security.
     - Automated responses using scripts under `/etc/` may be setup, for example to shut down encrypted container A if exploit B is detected on the network.
     - Non-threat events may also be detected, such as the presence of a coworker on the same network.

 - `dod-chromium`
     - Essentially a carbon-copy of the Chromium browser, but having our own package build + distribution system means the DoD can throw out changes
       which are seen as a threat to the DoD and add missing capabilities for the warfighter.

 - `dod-libreoffice`
     - Essentially a carbon-copy of the Libreoffice document suite, but having our own package build + distribution system means the DoD can throw out changes
       which are seen as a threat to the DoD and add missing capabilities for the warfighter.



# TODO

 - A package to provide code CI/CD and track project status would be great, but there are many providers and some research is in order.

 - A python script to setup 5-6 hephaestus-OS VMs (\~2gb memory each, ephemeral drives?) and simulate common network use cases. This will become
   a continuous test for the entire project, where a VM failing to respond or responding incorrectly will prevent the OS from being deployed.





