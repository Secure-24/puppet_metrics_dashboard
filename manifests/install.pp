class pe_metrics_dashboard::install(
  $add_dashboard_examples =   false,
  $influxdb_database_name =   'pe_metrics',
  $grafana_version =          '4.5.2',
  $grafana_http_port =        '3000',
) {

  case $::osfamily {

    'RedHat': {  
   
       yumrepo {'influxdb':
          ensure   => present,
          enabled  => 1,
          gpgcheck => 1,
          baseurl  => 'https://repos.influxdata.com/rhel/$releasever/$basearch/stable',
          gpgkey   => 'https://repos.influxdata.com/influxdb.key',
	  before => Package['influxdb'],
       }

       yumrepo { 'grafana-repo':
         ensure        => 'present',
         baseurl       => 'https://packagecloud.io/grafana/stable/el/6/$basearch',
         descr         => 'grafana-repository',
         enabled       => '1',
         repo_gpgcheck => '1',
         gpgcheck      => '1',
         gpgkey        => 'https://packagecloud.io/gpg.key https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana',
         sslverify     => '1',
         sslcacert     => '/etc/pki/tls/certs/ca-bundle.crt',
         before        => Class['grafana'],
       }
    }
    
    'Debian': {
      
      $_operatingsystem = downcase($::operatingsystem)	

      apt::source { 'influxdb':
        location => "https://repos.influxdata.com/${_operatingsystem}",
        release  => $::lsbdistcodename,
        repos    => 'stable',
        key      =>  {
          'id'     => '05CE15085FC09D18E99EFB22684A14CF2582E0C5',
          'source' => 'https://repos.influxdata.com/influxdb.key',
        },
	before => Package['influxdb'],
      }
    
      apt::source { 'grafana':
        location => 'https://packagecloud.io/grafana/stable/debian/', 
        release  => 'jessie',
        repos    => 'main',
        key      =>  {
          'id'     => '05CE15085FC09D18E99EFB22684A14CF2582E0C5',
          'source' => 'https://packagecloud.io/gpg.key',
        },
        before => Package['grafana'],
      }
    }

    default: {
      fail("$::osfamily installation not supported")
    }
  }

  package {'influxdb':
    ensure  => present,
  }

  service {'influxdb':
    ensure  => running,
    require => Package['influxdb'],
  }->

  exec {'create influxdb admin user':
    command => '/usr/bin/influx -execute "CREATE USER admin WITH PASSWORD \'puppet\' WITH ALL PRIVILEGES"',
    unless => '/usr/bin/influx -username admin -password puppet -execute \'show users\' | grep \'admin true\''
  }->

  exec {'create influxdb pe_metrics database':
    command => "/usr/bin/influx -username admin -password puppet -execute \"create database ${influxdb_database_name}\"",
    unless => "/usr/bin/influx -username admin -password puppet -execute \'show databases\' | grep ${$influxdb_database_name}"
  }

  class { 'grafana':
    install_method => 'repo',
    manage_package_repo => false,
    version => $grafana_version,
    cfg => {
      server   => {
        http_port      => $grafana_http_port,
      },
    },
  }->

  # Configure grafana to use InfluxDB
  grafana_datasource { "influxdb":
    grafana_url      => "http://localhost:${grafana_http_port}",
    type             => 'influxdb',
    database         => $influxdb_database_name,
    url              => 'http://localhost:8086',
    access_mode      => 'proxy',
    is_default       => true,
    user             => 'admin',
    password         => 'puppet',
    grafana_user     => 'admin',
    grafana_password => 'admin',
    require          => Service['grafana-server'],
  }

  if $add_dashboard_examples {
    grafana_dashboard { 'PuppetDB Performance':
      grafana_url       => "http://localhost:${grafana_http_port}",
      grafana_user      => 'admin',
      grafana_password  => 'admin',
      content           => file('pe_metrics_dashboard/PuppetDB_Performance.json'),
    }

    grafana_dashboard { 'PuppetDB Workload':
      grafana_url       => "http://localhost:${grafana_http_port}",
      grafana_user      => 'admin',
      grafana_password  => 'admin',
      content           => file('pe_metrics_dashboard/PuppetDB_Workload.json'),
    }
 
    grafana_dashboard { 'Puppetserver Performance':
      grafana_url       => "http://localhost:${grafana_http_port}",
      grafana_user      => 'admin',
      grafana_password  => 'admin',
      content           => file('pe_metrics_dashboard/Puppetserver_Performance.json'),
    }
  }

  ## install / enable kapacitor
  package {'kapacitor':
    ensure => present,
  }->

  service {'kapacitor':
    ensure  => running,
    enable  => true,
  }

  ## install / enable telegraf
  package {'telegraf':
    ensure => present,
  }->  

  service {'telegraf':
    ensure  => running,
    enable  => true,
  }

  ## install / enable chronograf

  package {'chronograf':
    ensure => present,
  }->

  service {'chronograf':
    ensure => running,
    enable => true,
  }

}
