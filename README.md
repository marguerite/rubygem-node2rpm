## NPKG (NodeJS Packaging Tool - Client)

openSUSE packages NodeJS modules and their dependencies in bundles to avoid maintenance headaches.

The key is a json file that emulates the result of npm shrinkwrap (without actually install npm).

This is the client that creates such json files on the packager's workstation.

The server side is nodejs-packaging that runs only on openSUSE Build Service as a build time requirement.

#### Installation

`gem install npkg`

or on openSUSE `sudo zypper in ruby%{ruby_ver}-rubygem-npkg`.
