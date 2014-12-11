Puppet::Type.newtype(:bmc_fw_ipmiflash) do
  desc "Updates the firmware on bmc servers using ipmi flash"

  ensurable

  newparam(:bmc_firmware) do 
    desc "Array of hashes containing [{component_name => (BIOS,BMC,FCB), version => 2.5.3, location => /path/to/bin}]"
  end

  newparam(:copy_to_tftp) do
    desc "2 element array, ['path to tftp share','path under tftp share']\nFor example: ['/var/lib/tftpshare','catalog1/firmware.bin']\n***Requires path param"
  end

  newparam(:path) do
    desc "The original firmware location path.  This has to be used in conjuction with to copy_to_tftp param"
  end

  newparam(:name) do
    desc "Firmware name, can be any unique name"
    isnamevar
  end

end
