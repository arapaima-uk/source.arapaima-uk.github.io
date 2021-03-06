+++
title=  'Using Vagrant to create a Virtual Machine running SQL Server on CentOS Linux'
date =  "2017-06-17"
tags = ["Vagrant", "SQL Server", "Linux"]
draft = false
+++

In my mind, the ability to do this kind of thing is the really big "win" with SQL Server on Linux. In their own words, 

>[Vagrant](https://www.vagrantup.com/) is a tool for building and managing virtual machine environments in a single workflow. With an easy-to-use workflow and focus on automation, Vagrant lowers development environment setup time, increases production parity, and makes the "works on my machine" excuse a relic of the past.

I've been doing [presentations]({{< relref "fixed/Speaking.md">}}) at conferences and meetups for a few years, so I'm familiar with the pain of setting up "Demo VMs" for SQL Server on Windows. I also have less than fond memories of setting up and maintaining multiple VMs on a single host to reproduce client problems with clustering, replication, etc.; fortunately I don't tend to get involved with this kind of thing too much these days, so it's not in the scope of this example.

Anyway, with the advent of SQL Server on Linux, it struck me that [Vagrant](https://www.vagrantup.com/), which I'd used for some other stuff in the "day job" might be a way out of this spiral of despair.  

The promise is that having set up a couple of config files, we can stand up a new VM with everything configured and in the right place, merely by typing `vagrant up` at a command prompt, and remove it again by typing `vagrant destroy`. If we want to keep it around for another day, `vagrant halt` is at our disposal. We can even `ssh` to our new VM by typing `vagrant ssh`, without any fiddling around with keys or passwords.

## Preamble
Yes, I'm aware it's possible to manage Windows guests with Vagrant, even from a Windows host, but my experience of trying this is that it's a world of pain, not least because the Windows box files are 800lb gorillas. The most complete attempt I've seen has been by [chocolately](https://chocolatey.org/) creator [Rob Reynolds](https://github.com/ferventcoder/vagrant-windows-puppet), who I suppose has (or had) some fairly unique needs in this area.

My own use case is further complicated by the fact that I've been using [Fedora Linux](https://getfedora.org/) on the desktop for the last few years, which doesn't _really_ support Virtualbox - though I'm aware it does _mostly_ work - but prefers [kvm](https://www.linux-kvm.org)-based virtual machines which can be managed through a number of utilities, including the supposedly idiot-proof [Gnome Boxes](https://wiki.gnome.org/Apps/Boxes). There are some slightly outdated results from [Phoronix](http://www.phoronix.com/scan.php?page=article&item=ubuntu-1510-virt) that suggest there may be some performance gains from using KVM as opposed to Virtualbox.

## Anyway, on with the show...

There are three supported platforms (plus Docker) listed on the [installation guide](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup) for SQL Server on Linux, namely Ubuntu, Suse, and RedHat. 

Given that, I decided to proceed with the creation of a [Centos](https://www.centos.org/) VM, given that it's "quite like" RedHat, and also has a vendor-created image in the [Vagrant Catalog](https://atlas.hashicorp.com/centos/boxes/7) that supports libvirt (almost all boxes, including the Ubuntu ones, are VirtualBox only). Suse also has vendor images for libvirt, but I haven't used Suse Linux since the Spice Girls were topping the charts and wasn't inclined to investigate further.

### The Vagrantfile

The [Vagrantfile](https://www.vagrantup.com/docs/vagrantfile/) is a file called `Vagrantfile` that is used to tell Vagrant what the VM you want to create needs to look like.

In this case it's fairly simple, but I've left the autogenerated comments in the version in the [github repo that accompanies this post](https://github.com/gavincampbell/VagrantSqlServerCentosEtc) (they're useful if, as is almost certain, you want to reproduce this on a slighly different platform to me, i.e. Virtualbox!), so I've extracted the highlights to a [gist](https://gist.github.com/gavincampbell/a9b920ff7b1c7f3547aeeca46e186050) here.

{{<gist gavincampbell a9b920ff7b1c7f3547aeeca46e186050>}}

We specify the "base box", in this case Centos 7 on which our VM is going to be based. After that, we just specify the ways in which our VM is going to diverge from this base. In our case, we are setting up a forwarded port for 1433, so that clients on the host can connect to the SQL Server as if it were "local". 

We're increasing the default memory allocation to the VM from the default (which I think is 512MB) to 4GB - the minimum requirement for SQL Server on Linux is 3.25, and I have read that the installer will fail if you have less than this available.

After that, we specify a shell script to run to set up everything else; In Vagrant-speak this is known as a "provisioner". 

Vagrant doesn't have to use shell scripts for configuration, it supports a number of alternative provisioners, such as the usual suspects of [Ansible](https://www.ansible.com/), [Chef](https://www.chef.io/chef/), and [Puppet](https://puppet.com/), in addition to a couple of others. 

The advantage of these latter approaches, of course, is that they are idempotent, making the scripts easy to build up over time; I intend to revisit this example, probably with Ansible, once SQL Server on Linux is generally available and the installation procedure is a bit less "dynamic". 

The shell script fetches updates with `yum` (for those more accustomed to Debian-derivatives such as Ubuntu this is like `apt`), then adds the Microsoft repository definitions to `yum`'s configuration. It also installs a package called `tcping` from another repo called `epel` (which stands for Extra Packages for Enterprise Linux), which we're going to need in our script. Having got everything downloaded, we install the SQL Server client and server, which are separate packages. 

Not only are they separate packages, they require different mechanisms for accepting the terms of the EULA; one requires an environment variable `ACCEPT_EULA=y`, and the other requires a parameter `accept-eula`!

We also pass the top-secret `sa` password as an environment variable; this is required to run the installation silently.

Having done all that, we wait for the service to start before proceeding. This is why `tcping` was required, it's among the simplest ways to figure out if there's anything listening on a given port.

Finally, we restore a database from a backup and run a script to install the tSQLt unit testing framework. By default, Vagrant will rsync the folder containing the `Vagrantfile` to a `/Vagrant` folder inside our VM, so we can simply put any files we need for provisioning (or for anything else) inside this folder. In this case, I've extracted the contents of the `tSQLt.zip` from the [tSQLt downloads page](http://tsqlt.org/downloads/). 

Originally, I had the database backup copied from the [original repo](https://github.com/microsoft/sql-server-samples) here too, but had to replace this with a call to `curl`; I'm glad to say I'd never run into the Github file size limit before! Obviously this makes the re-provisioning process a bit slower, it's best to have these large file dependencies somewhere local if you can manage it.

### What we didn't do

There's nothing in the (abbreviated) `Vagrantfile` about networking (other than the forwarded port), storage, logins, cores, etc. etc. All these things are configurable, but the point of this approach is that we trust Vagrant to "do the right thing" unless we specify otherwise. 

## The Moment of Truth

`vagrant up`

## Profit

![vscode on fedora connected to linux on centos in vagrant!](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/sql-linux-vagrant/vscode.png)

To be clear, this is a picture of Visual Studio Code, running on Fedora Linux 25 (the host), connected to SQL Server running on Centos 7.3 (the guest) in a virtual machine provisioned by vagrant. The mssql extension for Visual Studio Code is a very recent alpha; this was to do with .net core compatibility on "modern" versions of Linux.

The VM is a "regular" VM, you can see it here in the Fedora Virtual Machine Manager application with the console open showing the SQL Server process:

![vagrant vm opened in virt-manager showing the sql server process](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/sql-linux-vagrant/vmm.png)

## The Wrap

I was slightly surprised that all this worked as well as it did; not so much the Vagrant part as the SQL Server on Linux part, which is certainly more complete than when I last looked at it. In particular, I wasn't expecting to be able to install tSQLt on Linux - I did have to make a change to the `SetClrEnabled.sql` script that is distributed with tSQLt to turn off `clr strict security`, but apart from that it all went pretty smoothly. I have a [presentation about tSQLt](http://www.sqlsaturday.com/645/Sessions/Details.aspx?sid=63722) to do next month, which was one of the motivations for this exercise, and I'll certainly be setting aside some time in the next day or two to see if everything else works the way one might expect. If you want to try this out at home, and assuming your setup is roughly like mine (kvm rather than Virtualbox, vagrant already working, etc, etc):

``` bash
mkdir hereGoesNothing && cd hereGoesNothing;
git clone https://github.com/gavincampbell/VagrantSqlServerCentosEtc .
vagrant up
```

If your setup is different in relevant ways, there will be some steps between 2 and 3 where you install things and hack away at the `Vagrantfile`.

