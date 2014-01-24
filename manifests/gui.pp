# = Class icinga::gui
#
# @TODO - document this class
class icinga::gui {

  include apache
  include apache::mod::php
  include icinga::params
  $icinga_user = $icinga::params::icinga_user
  $icinga_group = $icinga::params::icinga_group
  $icinga_cmd_grp = $icinga::params::icinga_cmd_grp
  $admin_users = $icinga::params::admin_users
  $admin_group = $icinga::params::admin_group
  $ro_users = $icinga::params::ro_users
  $ro_group = $icinga::params::ro_group
  # check if we are running pgsql and fix port if it is set to default mysql port
  if $icinga::params::web_db_server == 'pgsql' and $icinga::params::web_db_port == 3306 {
    $web_db_port = 5432
  } else {
    $web_db_port = $icinga::params::web_db_port
  }

  # check if we are running pgsql and fix port if it is set to default mysql port
  if $icinga::params::ido_db_server == 'pgsql' and $icinga::params::ido_db_port == 3306 {
    $ido_db_port = 5432
  } else {
    $ido_db_port = $icinga::params::ido_db_port
  }

  # @TODO - why does this depend on the OS version? isn't dependent on Apache version?
  if $::operatingsystem == 'Fedora' and $::operatingsystemrelease >= 18 {
    $apache_allow_stanza = "    Require all granted\n"
  } else {
    $apache_allow_stanza = "    Order allow,deny\n    Allow from all\n"
  }

  if $icinga::params::gui_type =~ /^(classic|both)$/ {
    file { 'icingacgicfg':
      path    => '/etc/icinga/cgi.cfg',
      owner   => $icinga_user,
      group   => $icinga_group,
      mode    => '0644',
      content => template('icinga/cgi.cfg.erb'),
    }
    file { '/var/log/icinga/gui':
      ensure => directory,
      owner  => $icinga_user,
      group  => $icinga_cmd_grp,
      mode   => '2775',
    }
  }

  ## need to setup an exec to clean the web cache if these files change
  ## needs to run /usr/bin/icinga-web-clearcache
  if $icinga::params::gui_type =~ /^(web|both)$/ {
    file { '/etc/icinga-web/conf.d/databases.xml':
      owner   => root,
      group   => root,
      mode    => '0644',
      content => template('icinga/databases.xml.erb'),
    }
    file { '/etc/icinga-web/conf.d/auth.xml':
      owner   => root,
      group   => root,
      mode    => '0644',
      content => template('icinga/auth.xml.erb'),
    }
    # this still needs work
    #file { "/etc/icinga-web/conf.d/access.xml":
    #  owner   => root,
    #  group   => root,
    #  mode    => 644,
    #  content => template('icinga/access.xml.erb'),
    #}
    file { '/var/cache/icinga-web':
      ensure => directory,
      owner  => $apache::params::user,
      group  => $apache::params::group,
      mode   => '0775',
    }
    file { '/var/log/icinga/web':
      ensure => directory,
      owner  => $icinga_user,
      group  => $icinga_cmd_grp,
      mode   => '2775',
    }
  }

  # I'd prefer to convert this all over to the real, native Apache::Vhost
  # type, but that's more work than I want to invest right now, and it's
  # also going to be pretty hard with the IfModule blocks...
  $ldap_binddn = $icinga::params::ldap_binddn
  $ldap_bindpw = $icinga::params::ldap_bindpw
  $ldap_userattr = $icinga::params::ldap_userattr
  $ldap_authoritative = $icinga::params::ldap_authoritative
  $auth_conf = template($icinga::params::auth_template)

  # directory hashes to be passed into the apache::vhost
  $dir_classic = { }
  $dir_classic[$icinga::params::icinga_cgi_path_real] = {
    allow_override => 'None',
    options        => 'ExecCGI',
  }

  $directories = { }
  case $icinga::params::gui_type {
    'classic': {
      $gui_frag = template('icinga/gui_classic_conf.erb') # REMOVE
      $directories[$icinga::params::icinga_cgi_path_real] = $dir_classic
    }
    'web': {
      $gui_frag = template('icinga/gui_web_conf.erb')
    }
    'both': {
      $gui_frag = template('icinga/gui_classic_conf.erb', 'icinga/gui_web_conf.erb')
    }
    default: {
      $gui_frag = ''
    }
  }

  if ( $icinga::params::perfdata == true and $icinga::params::perfdatatype == 'pnp4nagios' ) {
    $perf_frag = template('icinga/pnp4nagios_apache.erb')
  } else {
    $perf_frag = ''
  }
  $custom_frag = "${gui_frag}\n${perf_frag}"

  # end interim hackery

  if $icinga::params::web_auth_type == 'ldap' {
    require apache::mod::authnz_ldap
  }

  $docroot = $icinga::params::gui_type ? {
    'web'   => '/usr/share/icinga-web/pub',
    default => '/usr/share/icinga/'
  }
  apache::vhost { $icinga::params::webhostname:
    ensure             => 'present',
    port               => $icinga::params::web_port,
    vhost_name         => '*',
    servername         => $icinga::params::webhostname,
    serveraliases      => [$::hostname, $::fqdn],
    access_log_file    => 'icinga-web-access_log',
    access_log_format  => 'combined',
    error_log_file     => 'icinga-web-error_log',
    docroot            => $docroot,
    docroot_owner      => root,
    docroot_group      => root,
    custom_fragment    => $custom_frag,
  }

  if ( $icinga::params::ssl == true ) {
    include apache::ssl

    Apache::Vhost[$icinga::params::webhostname] {
      ssl         => true,
      ssl_cipher  => $icinga::params::ssl_cypher_list,
      ssl_cert    => "${apache::params::ssl_certs_dir}/${icinga::params::webhostname}.crt",
      ssl_key     => "${apache::params::ssl_certs_dir}/${icinga::params::webhostname}.key",
      ssl_options => '+FakeBasicAuth +ExportCertData +StdEnvVars +StrictRequire',
    }

    if ( $icinga::params::ssl_cacrt ) {
      Apache::Vhost[$icinga::params::webhostname] {
        ssl_ca => $icinga::params::ssl_cacrt,
      }
    }

    if ( $icinga::params::manage_ssl == true ) {
      if ! defined(File["ssl_key_${icinga::params::webhostname}"]) {
        file { "ssl_key_${icinga::params::webhostname}":
          path   => "${apache::params::ssl_certs_dir}/${icinga::params::webhostname}.key",
          owner  => root,
          group  => root,
          mode   => '0644',
          source => "${icinga::params::ssl_cert_source}/${icinga::params::webhostname}.key",
          notify => Service[httpd],
        }
      }
      if ! defined(File["ssl_crt_${icinga::params::webhostname}"]) {
        file { "ssl_crt_${icinga::params::webhostname}":
          path   => "${apache::params::ssl_certs_dir}/${icinga::params::webhostname}.crt",
          owner  => root,
          group  => root,
          mode   => '0644',
          source => "${icinga::params::ssl_cert_source}/${icinga::params::webhostname}.crt",
          notify => Service[httpd],
        }
      }
    }
  }

}

