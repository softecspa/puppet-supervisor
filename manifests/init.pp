# Install supervisor daemon
class supervisor (
  $ensure = present,
  $services = {},
) {

  include supervisor::params

  validate_re($ensure, [ '^installed$', '^present$', '^absent$', '^latest$' ])
  validate_hash($services)

  ensure_resource(
    'package',
    $supervisor::params::package,
    { ensure => $ensure }
  )

  file {
    $supervisor::params::conf_dir:
      ensure  => directory,
      purge   => true,
      require => Package[$supervisor::params::package];
    ['/var/log/supervisor', '/var/run/supervisor']:
      ensure  => directory,
      purge   => true,
      backup  => false,
      require => Package[$supervisor::params::package];
    $supervisor::params::conf_file:
      content => template('supervisor/supervisord.conf.erb'),
      require => Package[$supervisor::params::package],
      notify  => Service[$supervisor::params::system_service];
  }

  file {'/var/log/supervisor/archives':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0664',
  }

  logrotate::file { 'supervisor':
    log          => '/var/log/supervisor/supervisord.log',
    interval     => 'daily',
    rotation     => '5',
    options      => [ 'missingok', 'compress', 'notifempty' ],
    archive      => true,
    olddir       => '/var/log/supervisor/archives/supervisor',
    olddir_owner => 'root',
    olddir_group => 'adm',
    olddir_mode  => '644',
    create       => '664 root root',
    postrotate   => '/usr/bin/killall -USR2 supervisord',
    require      => File['/var/log/supervisor/archives'],
  }

  service { $supervisor::params::system_service:
    ensure     => running,
    enable     => true,
    hasrestart => false,
    # patched: 'restart' non funziona
    restart    => '/etc/init.d/supervisor force-stop && /etc/init.d/supervisor start',
    require    => Package[$supervisor::params::package];
  }

  # hook to let supervisor::service reload supervisor config
  exec { 'supervisor::update':
      command     => '/usr/bin/supervisorctl update',
      logoutput   => on_failure,
      refreshonly => true,
      require     => Service[$supervisor::params::system_service];
  }

  # ensure merging of hiera levels
  $hiera_services = hiera_hash('supervisor::services', {})
  $real_services = $hiera_services ? {
    undef   => $services,
    default => $hiera_services,
  }

  if $real_services {
    create_resources('supervisor::service', $real_services)
  }

}
