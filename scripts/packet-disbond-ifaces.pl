#!/usr/bin/perl -w

use strict;

sub update_interfaces($$$$) {

        my ($iface0, $iface1, $iface1_ip, $iface1_netmask) = @_;


        rename("/etc/network/interfaces", "/etc/network/interfaces.backup");
        open(OUT, ">/etc/network/interfaces");
        select(OUT);
        open(IFACES, "<", "/etc/network/interfaces.backup") or die "can'open interfaces: $!";
        while (<IFACES>) {
        restart:
                # change this to use the first interface
                if (/^auto bond0(.*)/) {
                        print("auto ${iface0}$1\n");
                        next;
                }

                # change this line to use the first interface
                if (/^iface bond0(.*)/) {
                        print("iface ${iface0}$1\n");
                        while (<IFACES>) {
                                # ignore bond lines
                                next if /bond-/;

                                # comment out the adding the /8 route
                                if (/^(\s+)(post-up route add -net 10\.0\.0\.0\/8.*)$/) {
                                        print("$1# $2\n");
                                        next;
                                }

                                # print evertying else as is
                                if (/^(\s+.+)$/) {
                                        print;
                                        next;
                                }

                                # done with this interface
                                goto restart;
                        }

                }

                # ignore everyting from the first interface
                next if /^auto ${iface0}/;
                if (/^iface ${iface0}(.*)/) {
                        while (<IFACES>) {
                                next if /^\s/;
                                goto restart;
                        }
                }

                # ignore everyting from the second interface
                next if /^auto ${iface1}/;
                if (/^iface ${iface1}(.*)/) {
                        while (<IFACES>) {
                                next if /^\s/;
                                goto restart;
                        }
                }

                if (defined($_)) {
                        print;
                }
        }

        print("auto $iface1\n");
        print("iface  $iface1 inet static\n");
        print("    address $iface1_ip\n");
        print("    netmask $iface1_netmask\n");
        select(STDOUT);
}

my $num_args = $#ARGV + 1;
die "Usage: $0 <iface1_ip> [<iface1_netmask>]\n" unless $num_args >= 1;
my $iface1_ip = $ARGV[0];
my $iface1_netmask =($num_args >=2) ? $ARGV[1] : "255.255.255.0";

# get the two interfaces
open(SLAVES, "<", "/sys/class/net/bond0/bonding/slaves") or die "can't open slaves: $!";
chomp($_ = <SLAVES>);
(my $if0, my $if1)  = split(' ');
system("ip link delete dev bond0");
system("ifdown $if0");
system("ifdown $if1");
update_interfaces($if0, $if1, $iface1_ip, $iface1_netmask);
system("ifup $if0");
system("ifup $if0:0");
system("ifup $if1");
