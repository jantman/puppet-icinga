# == Class: icinga::psqldb_ido
#
# Setup the Icinga IDO database, user, and load initial schema.
#
# Only usable if PostgresQL is running on localhost!
#
# === Parameters:
#
# [*database_name*]
#   name of the database
#   (default 'icinga-ido')
#
# [*database_username*]
#   username to access the database
#   (default 'icinga-ido')
#
# [*database_password*]
#   password for $database_user
#  (default 'icinga-ido')
#
# === Variables:
#
# This module uses no global variables.
#
# === Actions:
#   - instantiate postgresql::db resource with the appropriate params
#   - write a per-user .pgpass file for the icinga user
#   - if the DB is empty, load the initial SQL file
#
# === Notes:
#
#
# === Examples:
#
#   class { 'icinga::psqldb_ido': }
#
# === Authors:
#
# Jason Antman <jason@jasonantman.com>
#
# === Copyright
#
# Copyright 2013 Cox Media Group.
#
class icinga::psqldb_ido(
  $database_name      = 'icinga_ido',
  $database_username  = 'icinga-ido',
  $database_password  = 'icinga-idopass',
  $database_port      = 5432,
  $icinga_user        = 'icinga',
  $icinga_home        = '/var/spool/icinga',
  $ido_sql_file       = '$(find /usr/share/doc/icinga-ido* -name \"pgsql.sql\" | head -1)'
) {

  # create the database and user
  postgresql::server::db{ $database_name:
    user     => $database_username,
    password => postgresql_password($database_username, $database_password),
    grant    => 'ALL',
  }

  $pgpass_path = "${icinga_home}/.pgpass"

  if ! defined(File[$pgpass_path]) {
    file { $pgpass_path:
      ensure  => present,
      path    => $pgpass_path,
      owner   => $icinga_user,
      mode    => '0600',
    }
  }

  # the file_line type comes from puppetlabs/stdlib
  file_line{ 'icinga-pgpass-ido':
    ensure  => present,
    path    => $pgpass_path,
    line    => "localhost:${database_port}:${database_name}:${database_username}:${database_password}",
    require => File[$pgpass_path],
  }

  exec { 'psql-load-ido-db':
    user    => $icinga_user,
    command => "/usr/bin/psql -d ${database_name} -h localhost -p ${database_port} -U ${database_username} < ${ido_sql_file}",
    unless  => "/usr/bin/psql -d ${database_name} -h localhost -p ${database_port} -U ${database_username} -c \"SELECT version FROM icinga_dbversion WHERE name='idoutils';\"",
    require => [ Package['icinga-idoutils-libdbi-pgsql'],
                Postgresql::Server::Db[$database_name],
                File_line['icinga-pgpass-ido'] ],
  }

}
