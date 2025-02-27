#!/usr/bin/perl
use strict;

use AnyEvent::MQTT;
use AnyEvent::Run;

my $config = {
    mqtt_host => $ENV{MQTT_HOST} || 'localhost',
    mqtt_port => $ENV{MQTT_PORT} || '1883',
    mqtt_user => $ENV{MQTT_USER},
    mqtt_password => $ENV{MQTT_PASSWORD},
    mqtt_prefix => $ENV{MQTT_PREFIX} || 'home/x10',
    mqtt_retain_re => qr/$ENV{MQTT_RETAIN_RE}/i || qr//, # retain everything
    heyu_cmd => $ENV{HEYU_CMD} || 'heyu',
};

my $mqtt = AnyEvent::MQTT->new(
    host => $config->{mqtt_host},
    port => $config->{mqtt_port},
    user_name => $config->{mqtt_user},
    password => $config->{mqtt_password},
);

sub receive_mqtt_set {
    my ($topic, $message) = @_;
    $topic =~ m{\Q$config->{mqtt_prefix}\E/(.*)/set};
    my $device = $1;
    if ($device eq "raw") { # send 'raw' message, for example "xpreset o3 32" 
        AE::log info => "X10 sending heuy commmand $message";
        system($config->{heyu_cmd}, lc $message);
    } elsif ($message =~ m{^on$|^off$}i) {
        AE::log info => "X10 switching device $device $message";
        system($config->{heyu_cmd}, lc $message, $device);
    } 
}

sub send_mqtt_status {
    my ($device, $status, $dimlevel) = @_;
    $mqtt->publish(topic => "$config->{mqtt_prefix}/$device", message => sprintf('"%s"', $status ? 'on' : 'off'));
}

my $addr_queue = {};
sub process_heyu_line {
    my ($handle, $line) = @_;
    if ($line =~ m{Monitor started}) {
        AE::log note => "watching heyu monitor";
    } elsif ($line =~ m{  \S+ addr unit\s+\d+ : hu ([A-Z])(\d+)}) {
        my ($house, $unit) = ($1, $2);
        $addr_queue->{$house} ||= {};
        $addr_queue->{$house}{$unit} = 1;
    } elsif ($line =~ m{  \S+ func\s+(\w+) : hc ([A-Z])}) {
        my ($cmd, $house) = ($1, $2);
        if ($addr_queue->{$house}) {
            for my $k (keys %{$addr_queue->{$house}}) {
                process_heyu_cmd(lc $cmd, "$house$k", -1);
            }
            delete $addr_queue->{$house};
        }
    } elsif ($line =~ m{  \S+ func\s+(\w+) : hu ([A-Z])(\d+)  level (\d+)}) {                                                                                                                         
	my ($cmd, $house, $unit, $level) = ($1, $2, $3, $4);                                                                                                                                               
	process_heyu_cmd(lc $cmd, "$house$unit", $level);                                                                                                                              
    }
}

sub process_heyu_cmd {
    my ($cmd, $device, $level) = @_;
    AE::log info => "Sending MQTT status for $device: $cmd";
    if ($cmd eq 'on') {
        send_mqtt_status($device, 1);
    } elsif ($cmd eq 'off') {
        send_mqtt_status($device, 0);
    } elsif ($cmd eq 'xpreset') {
        send_mqtt_status($device, 1, $level);
    }
}

$mqtt->subscribe(topic => "$config->{mqtt_prefix}/+/set", callback => \&receive_mqtt_set)->cb(sub {
    AE::log note => "subscribed to MQTT topic $config->{mqtt_prefix}/+/set";
});

my $monitor = AnyEvent::Run->new(
    cmd => [ $config->{heyu_cmd}, 'monitor' ],
    on_read => sub {
        my $handle = shift;
        $handle->push_read( line => \&process_heyu_line );
    },
    on_error => sub {
        my ($handle, $fatal, $msg) = @_;
        AE::log error => "error running heyu monitor: $msg";
    },
);

AnyEvent->condvar->recv;
