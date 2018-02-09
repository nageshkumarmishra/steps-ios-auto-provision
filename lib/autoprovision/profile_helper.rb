require_relative 'portal/profile'
require_relative 'portal/app'

# ProfileInfo
class ProfileInfo
  attr_accessor :path
  attr_accessor :portal_profile

  def initialize(path, portal_profile)
    @path = path
    @portal_profile = portal_profile
  end
end

# ProfileHelper ...
class ProfileHelper
  def initialize(project_helper, certificate_helper)
    @project_helper = project_helper
    @certificate_helper = certificate_helper

    @managed_profiles = {}
    @manual_profiles = {}
  end

  def ensure_profiles(distribution_type)
    distribution_types = [distribution_type]
    if distribution_type != 'development' && @certificate_helper.certificate_info('development')
      distribution_types = ['development'].concat(distribution_types)
    end

    Log.debug("distribution_types: #{distribution_types}")

    distribution_types.each do |distr_type|
      if @project_helper.uses_xcode_auto_codesigning?
        ensure_xcode_managed_profiles(distr_type)
      else
        ensure_manual_profiles(@certificate_helper.certificate_info(distr_type).portal_certificate, distr_type)
      end
    end
  end

  def profiles_by_bundle_id(distribution_type)
    if @project_helper.uses_xcode_auto_codesigning?
      @managed_profiles[distribution_type]
    else
      @manual_profiles[distribution_type]
    end
  end

  private

  def ensure_xcode_managed_profiles(distribution_type)
    targets = @project_helper.targets
    targets.each do |target|
      target_name = target.name
      bundle_id = @project_helper.target_bundle_id(target_name)
      entitlements = @project_helper.target_entitlements(target_name) || {}

      Log.print("checking xcode managed #{distribution_type} profile for target: #{target_name} (#{bundle_id}) with #{entitlements.length} services on developer portal")
      portal_profile = Portal::ProfileHelper.ensure_xcode_managed_profile(bundle_id, entitlements, distribution_type)

      Log.print("downloading development profile: #{portal_profile.name}")
      profile_path = write_profile(portal_profile)
      Log.debug("profile path: #{profile_path}")

      profile_info = ProfileInfo.new(profile_path, portal_profile)
      @managed_profiles[distribution_type] ||= {}
      @managed_profiles[distribution_type][bundle_id] = profile_info
    end
  end

  def ensure_manual_profiles(certificate, distribution_type)
    targets = @project_helper.targets
    targets.each do |target|
      target_name = target.name
      bundle_id = @project_helper.target_bundle_id(target_name)
      entitlements = @project_helper.target_entitlements(target_name) || {}

      Log.print("checking app for target: #{target_name} (#{bundle_id}) on developer portal")
      app = Portal::AppHelper.ensure_app(bundle_id)

      Log.debug('sync app services')
      app = Portal::AppHelper.sync_app_services(app, entitlements)

      Log.print("ensure #{distribution_type} profile for target: #{target_name} on developer portal")
      portal_profile = Portal::ProfileHelper.ensure_manual_profile(certificate, app, distribution_type)

      Log.print("downloading development profile: #{portal_profile.name}")
      profile_path = write_profile(portal_profile)
      Log.debug("profile path: #{profile_path}")

      profile_info = ProfileInfo.new(profile_path, portal_profile)
      @manual_profiles[distribution_type] ||= {}
      @manual_profiles[distribution_type][bundle_id] = profile_info
    end
  end

  def write_profile(profile)
    home_dir = ENV['HOME']
    raise 'failed to determine xcode provisioning profiles dir: $HOME not set' if home_dir.to_s.empty?

    profiles_dir = File.join(home_dir, 'Library/MobileDevice/Provisioning Profiles')
    FileUtils.mkdir_p(profiles_dir) unless File.directory?(profiles_dir)

    profile_path = File.join(profiles_dir, profile.uuid + '.mobileprovision')
    Log.warn("profile already exists at: #{profile_path}, overwriting...") if File.file?(profile_path)

    File.write(profile_path, profile.download)
    profile_path
  end
end