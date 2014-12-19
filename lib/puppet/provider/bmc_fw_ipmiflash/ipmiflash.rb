provider_path = Pathname.new(__FILE__).parent.parent
require 'puppet/bmc/util'
require 'asm/util'
require 'fileutils'

Puppet::Type.type(:bmc_fw_ipmiflash).provide(
  :ipmiflash,
) do
  BMC_BIN = "/opt/dell/pec/bmc"
  IPMI_TOOL = "/usr/bin/ipmitool"
  IPMI_FLASH = "/opt/dell/pec/ipmiflash"
  
  def exists?
    @firmwares = ASM::Util.asm_json_array(resource[:bmc_firmware])
    @copy_to_tftp = resource[:copy_to_tftp]
    @installed_versions = {}
    up_to_date = fw_up_to_date?
    Puppet.debug("#{up_to_date}")
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
      when 'bios'
        fw['version'] != @installed_versions['BIOSversion'] ? upgrades_needed << fw : nil
      when 'bmc'
        fw['version'] != @installed_versions['BMCversion'] ? upgrades_needed << fw : nil
      when 'fcb'
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
      resp = %x[#{cmd}]
      if resp.length == 0
        Puppet.debug("BMC 0 length response received, retrying after sleep")
        sleep sleeptime
        sleeptime += 30
      elsif resp.include? 'unresponsive BMC'
        Puppet.debug("BMC connection failed, retrying after sleep")
      else
        Puppet.debug("BMC RESPONSE: #{resp}")
        return resp.encode('utf-8', 'binary', :invalid => :replace, :undef => :replace)
      end
    end
    raise Puppet::Error, "Could not connect to the BMC endpoint"
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
      if @copy_to_tftp
        move_to_tftp(resource[:path])
      end
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
    cmd = "#{IPMI_FLASH} -p -H #{transport[:host]} -U #{transport[:user]} -Pi #{transport[:password]} #{firmware['component_name']} #{firmware['location']}"
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

  def move_to_tftp(path)
    Puppet.debug("Copying files to TFTP share")
    tftp_share = @copy_to_tftp[0]
    tftp_path = @copy_to_tftp[1]
    full_tftp_path = tftp_share + "/" + tftp_path
    tftp_dir = full_tftp_path.split('/')[0..-2].join('/')
    if !File.exist? tftp_dir
      FileUtils.mkdir_p tftp_dir
    end
    FileUtils.cp path, full_tftp_path
    FileUtils.chmod_R 0755, tftp_dir
  end
end
