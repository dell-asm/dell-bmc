provider_path = Pathname.new(__FILE__).parent.parent
require 'puppet/bmc/util'
require 'asm/util'

Puppet::Type(:bmc_fw_ipmiflash).provide(
  :ipmiflash,
  :parent => Puppet::Provider::Bmc
) do
  
  def exists?
    @firmwares = ASM::Util.asm_json_array(resource[:bmc_firmware])
    check_versions
  end

  def check_versions
  end

  def run_bmc(cmd)
    sleeptime = 30
    4.times do
      resp = %x[#{cmd}]
      if resp.length == 0
        Puppet.debug("BMC 0 length response received, retrying after sleep")
        sleep sleeptime
        sleeptime += 30
      elsif res.include? 'unresponsive BM'
