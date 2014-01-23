
class icinga::config {

  include icinga::params

  $icinga_user = $icinga::params::icinga_user
  $icinga_group = $icinga::params::icinga_group
  $icinga_cmd_grp = $icinga::params::icinga_cmd_grp
  $notifications_bool2num = bool2num($icinga::params::notifications)
  $embedded_perl = $icinga::params::embedded_perl
  $perfdata = $icinga::params::perfdata
  $perfdata_bool2num = bool2num($icinga::params::perfdata)
  $perfdatatype = $icinga::params::perfdatatype
  $admin_group = $icinga::params::admin_group
  $nagios_plugins = $icinga::params::nagios_plugins
  $nagios_extra_plugins = $icinga::params::nagios_extra_plugins
  $db_password = $icinga::params::db_password
  $email_password = $icinga::params::email_password
  $check_timeout = $icinga::params::check_timeout
  $clickatell_api_id = hiera('monitoring::clickatell_api_id', undef)
  $clickatell_username = hiera('monitoring::clickatell_username', undef)
  $clickatell_password = hiera('monitoring::clickatell_password', undef)
  $is_pbx = hiera('is_pbx', false)
  $pbx_mngr_pw = hiera('monitoring::pbx_mngr_pw', undef)
  $debug = $icinga::params::debug
  $admin_email = $icinga::params::admin_email
  $admin_pager = $icinga::params::admin_pager
  $stalking = $icinga::params::stalking
  $flap_detection = $icinga::params::flap_detection
  $use_monitoring = $icinga::params::use_monitoring # enable rendhalver/monitoring specific stuff

  file { 'icingacfg':
    name => '/etc/icinga/icinga.cfg',
    owner => $icinga_user,
    group => $icinga_group,
    mode => 644,
    notify => Class[icinga::service],
    content => template('icinga/icinga.cfg.erb'),
  }

  file { 'idomodcfg':
    name => '/etc/icinga/idomod.cfg',
    owner => $icinga_user,
    group => $icinga_group,
    mode => 644,
    notify => Class[icinga::service],
    content => template('icinga/idomod.cfg.erb'),
  }

  file { 'icinga_resource':
    name => '/etc/icinga/resource.cfg',
    owner => $icinga_user,
    group => $icinga_group,
    mode => 644,
    notify => Class[icinga::service],
    content => template('icinga/resource.cfg.erb'),
  }

  file { '/var/log/icinga':
    ensure => directory,
    owner => $icinga_user,
    group => $icinga_group,
    mode => 775,
  }

  file { '/var/log/icinga/archives':
    ensure => directory,
    owner => $icinga_user,
    group => $icinga_group,
    mode => 775,
  }

  file { '/var/spool/icinga':
    ensure => directory,
    owner => $icinga_user,
    group => $icinga_group,
    mode => 755,
  }

  file { '/var/spool/icinga/checkresults':
    ensure => directory,
    owner => $icinga_user,
    group => $icinga_group,
    mode => 775,
  }

  file { '/var/spool/icinga/cmd':
    ensure => directory,
    owner => $icinga_user,
    group => $icinga_cmd_grp,
    mode => 2755,
  }

}

