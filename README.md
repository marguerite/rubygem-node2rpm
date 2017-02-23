## Node2RPM (NodeJS Packaging Tool)

Node2RPM packages a node module and its dependencies into RPM as a bundle to avoid maintenance headaches.

It will:

* generate a dependency map in json format, containing all recursive dependencies for one node module.
* output a RPM specfile.

#### Installation

`gem install node2rpm`

or on openSUSE `sudo zypper in ruby%{ruby_ver}-rubygem-node2rpm`.
