provider_path = Pathname.new(__FILE__).parent.parent
require 'puppet/bmc/util'
require 'asm/util'
require 'fileutils'
require 'tmpdir'
require 'open3'

Puppet::Type.type(:bmc_fw_ipmiflash).provide(
  :ipmiflash,
) do
  BMC_BIN = "/opt/dell/pec/bmc"
  IPMI_TOOL = "/usr/bin/ipmitool"
  IPMI_FLASH = "/opt/dell/pec/ipmiflash"
  UNZIP = %x[which unzip].chop
  FIND = %x[which find].chop

  def exists?
    @firmwares = ASM::Util.asm_json_array(resource[:bmc_firmware])
    @installed_versions = {}
    up_to_date = fw_up_to_date?
    #Returns false if update is required
    up_to_date
  end

  def check_versions
    upgrades_needed = []
    cmd = "#{BMC_BIN} -H #{transport[:host]} allinfo"
    Puppet.debug("Getting host info")
    resp = run_cmd(cmd)
    get_versions(resp)
    Puppet.debug("firmwares: #{@firmwares}")
    @firmwares.each do |fw|
      case fw['component_name'].downcase
      when '159'
        fw['component_name'] = 'bios'
        fw['version'] != @installed_versions['BIOSversion'] ? upgrades_needed << fw : nil
      when 'bmc'##TODO Find id
        fw['version'] != @installed_versions['BMCversion'] ? upgrades_needed << fw : nil
      when 'fcb' ##TODO find id
        fw['version'] != @installed_versions['FCBversion'] ? upgrades_needed << fw : nil
      else
      end
    end
    @upgrades_needed = ASM::Util.asm_json_array(upgrades_needed)
  end

  def fw_up_to_date?
    check_versions
    if @upgrades_needed.size != 0
      return false
    else
      return true
    end
  end

  def run_cmd(cmd)
    sleeptime = 30
    4.times do
      std_out, std_err, status = Open3.capture3(cmd)
      if std_out.length == 0
        Puppet.debug("BMC 0 length response received, retrying after sleep")
        sleep sleeptime
        sleeptime += 30
      elsif std_out.include? 'unresponsive BMC'
        Puppet.debug("BMC connection failed, retrying after sleep")
        sleep sleeptime
        sleeptime += 30
      elsif std_err.length != 0
        Puppet.debug("ERROR: #{std_err}.\n Retrying after sleep.")
        sleep sleeptime
        sleeptime += 30
      elsif status.exitstatus != 0
        Puppet.debug("ERROR: Non-zero exit code returned.\n#{std_out}\n Retrying after sleep.")
        sleep sleeptime
        sleeptime += 30
      else
        Puppet.debug("RESPONSE: #{std_out}")
        return std_out.encode('utf-8', 'binary', :invalid => :replace, :undef => :replace)
      end
    end
    raise Puppet::Error, "API Call error. Failing after 4 retries.."
  end

  def get_versions(resp)
    resp.each_line do |line|
      if line.include? ('BIOS version'||'BMC version'||'FCB version')
        parse_info(line)
      end
   end
  end

  def parse_info(line)
    key = line.split(':')[0].gsub(' ','')
    val = line.split(':')[1].gsub(' ','').chop
    @installed_versions[key] = val
  end

  def create
    @upgrades_needed.each do |firmware|
      Puppet.debug("Upgrade needed for #{firmware}")
      mc_reset
      ipmi_flash(firmware)
    end
  end
  
  def mc_reset
    cmd = "#{IPMI_TOOL} -H #{transport[:host]} -U #{transport[:user]} -P #{transport[:password]} mc reset cold"
    resp = run_cmd(cmd)
    sleep 210
    check_for_ready
  end

  def check_for_ready
    cmd = "#{IPMI_TOOL} -H #{transport[:host]} -U #{transport[:user]} -P #{transport[:password]} fru"
    run_cmd(cmd)
  end

  def ipmi_flash(firmware)
    cmd = "#{IPMI_FLASH} -p -H #{transport[:host]} -U #{transport[:user]} -P #{transport[:password]} #{firmware['component_name']} #{firmware['location']}"
    resp = run_cmd(cmd)
    Puppet.debug("#{resp}")
    if resp.include? 'Error condition during update process'
      raise Puppet::Error, "Error condition during update process"
    else
      sleep 240
      check_for_ready
    end
  end

  def validate_update
    if fw_up_to_date?
      Puppet.debug("Firmware update applied successfully")
    else
      raise Puppet::Error, "Error updating firmware"
    end
  end

  def transport
    @transport ||= Puppet::Bmc::Util.get_transport()
  end

end
