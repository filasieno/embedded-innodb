# Embedded InnoDB 0.1

## Prerequisites

### Install Nix

Follow this [Nix installation guide](https://nix.dev/install-nix.html).

### Installing Embeddded InnoDB

#### Nix

fter you have successfully installed **Nix** execute the following:

```shell
git clone ....
```

#### Debian

*todo*.

#### RedHat Linux (rpm)

*todo*.


This is the source of Embedded InnoDB 0.1

The long term plan is to convert it incrementally to Zig. Starting with the tests.

So far only lightly tested on Ubuntu 23.10.

Instructions for compiling and installing, setup to compile with C++ 23.

1. cmake -G Ninja -DCMAKE_BUILD_TYPE=(debug|Release) .

2. ninja

3. #ninja install (not tested yet)

4. Enjoy!

Resources:

[https://nivethan.dev/devlog/extending-a-c-project-with-zig.html](https://nivethan.dev/devlog/extending-a-c-project-with-zig.html)
[https://zig.guide/working-with-c/abi/](https://zig.guide/working-with-c/abi/)
