Dell BMC Puppet Module
========
=======
# bmc

#### Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
3. [Setup](#setup)
    * [What bmc affects](#what-bmc-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with bmc](#beginning-with-bmc)
4. [Usage](#usage)
5. [Reference](#reference)
5. [Limitations](#limitations)
6. [Development](#development)

## Overview

This puppet module is used for managing bare-metal servers with the BMC API

## Module Description

Currently this module only suppoerts updating the bios firmware on BMC servers.
(tested with ... #TODO)

## Setup

### Firmware update requirements

* BIOS firmware binary
* Tftp server that will share binaries
* IPMIFlash (installed in default location [/opt/dell/pec])
* IPMITool 
* BMCTool (installed in default loaction [/opt/dell/pec])

## Usage

```puppet
bmc_fw_ipmiflash { "update":
        bmc_firmware => [{component_name => 'bios', version => '2.5.3', location => 'tftp://localhost/path/to/firmware.hdr'}],
        ensure       => present,
}
```

## Reference

### This Module Uses the following tools

* Baseboard Management Controller (http://www.dell.com/downloads/global/power/ps4q04-20040110-zhuo.pdf)
* IPMI Tool (http://linux.die.net/man/1/ipmitool)
* IPMI Flash 

## Limitations

This only supports a forced restart at this time.

