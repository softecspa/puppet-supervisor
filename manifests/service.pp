define supervisor::service(
  $command,
  $ensure=present,
  $enable=true,
  $numprocs=1,
  $priority=999,
  $autorestart='unexpected',
  $startsecs=1,
  $retries=3,
  $exitcodes='0,2',
  $stopsignal='TERM',
  $stopwait=10,
  $user='',
  $group='',
  $redirect_stderr=false,
  $stdout_logfile='',
  $stdout_logfile_maxsize='250MB',
  $stdout_logfile_keep=10,
  $stderr_logfile='',
  $stderr_logfile_maxsize='250MB',
  $stderr_logfile_keep=10,
  $environment='',
  $chdir='',
  $umask=''
) {

  include supervisor::params

  $autostart = $ensure ? {
    running => true,
    stopped => false,
    default => false
  }

  $ensure_real = $enable? {
    false   => 'absent',
    default => undef
  }

  $content_real = $enable? {
    true    => template('supervisor/service.ini.erb'),
    default => undef
  }

  $ensure_logdir = $ensure? {
    purged  => absent,
    default => directory,
  }

  $real_user = $user? {
    ''      => 'root',
    default => $user
  }

  $real_group = $group? {
    ''      => 'root',
    default => $group
  }

  $recurse = $ensure?{
    purged  => true,
    default => false
  }

  $force = $ensure? {
    purged  => true,
    default => false
  }

  file {
    "${supervisor::params::conf_dir}/${name}.ini":
      ensure  => $ensure_real,
      content => $content_real,
      require => File[$supervisor::params::conf_dir, "/var/log/supervisor/${name}"],
      notify  => Exec['supervisor::update'];
    "/var/log/supervisor/${name}":
      ensure  => $ensure_logdir,
      owner   => $real_user,
      group   => $real_group,
      mode    => '0750',
      recurse => $recurse,
      force   => $force,
  }

  if ($ensure == 'running' or $ensure == 'stopped') {
    service { "supervisor::${name}":
      ensure   => $ensure,
      provider => base,
      restart  => "/usr/bin/supervisorctl restart ${name}",
      start    => "/usr/bin/supervisorctl start ${name}",
      status   => "/usr/bin/supervisorctl status | awk '/^${name}/{print \$2}' | grep '^RUNNING$'",
      stop     => "/usr/bin/supervisorctl stop ${name}",
      require  => [ Package['supervisor'], Service[$supervisor::params::system_service] ];
    }
  }

  logrotate::file { "supervisor-${name}":
    log          => "/var/log/supervisor/${name}/*.out /var/log/supervisor/${name}/*.err",
    interval     => 'daily',
    rotation     => '5',
    options      => [ 'missingok', 'compress', 'notifempty' ],
    archive      => true,
    olddir       => "/var/log/supervisor/archives/${name}/",
    olddir_owner => 'root',
    olddir_group => 'root',
    olddir_mode  => '664',
    create       => '664 root root',
    postrotate   => '/usr/bin/killall -USR2 supervisord'
  }
}
