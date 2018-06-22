#!/usr/bin/perl

# $Id$
=pod

=head1 NAME

template_recursion.pl - recursively apply a template

=head1 SYNOPSIS

  template_recursion.pl --source-path source_path --dest-path dest_path

=head1 DESCRIPTION



=head1 OPTIONS


=cut


use strict;
use warnings;

use Pod::Usage;
use FindBin qw($RealBin $Script);
use Data::Dumper;
use Template;
use File::Basename;
use IO::File;
use File::Spec;
use Template;

use Getopt::Long;
my $DEBUG=0;
my $OPTIONS_VALUES = {};
my $OPTIONS=[
	'source-path=s',
	'dest-path=s',
	'config-file=s',
];

GetOptions(
	$OPTIONS_VALUES,
	@$OPTIONS,
)
or pod2usage(
	-message => "Invalid options specified.\n"
		. "Please perldoc this file for more information.",
	-exitval => 1
);

if (! -e $OPTIONS_VALUES->{'source-path'} )
{
	pod2usage(
		-message => "--source-path does not exist\n"
			. "Please perldoc this file for more information.",
		-exitval => 1
	)
}

if (! defined $OPTIONS_VALUES->{'dest-path'}
	|| $OPTIONS_VALUES->{'dest-path'} eq ""
)
{
	pod2usage(
		-message => "please specify --dest-path\n"
			. "Please perldoc this file for more information.",
		-exitval => 1
	)
}

our @UP_PATH_COMPONENTS;
our @POST_PATH_COMPONENTS;

my $SCRIPT_ABS_PATH;
my @SCRIPT_PATH_PARTS;
our $PROJECT_NAME;

our $SCRIPT_WITHOUT_EXTENSION = $Script;
$SCRIPT_WITHOUT_EXTENSION =~ s/(\.[^.]+)$//;

our $CHOSEN_BIN = $RealBin;
$SCRIPT_ABS_PATH = File::Spec->rel2abs($CHOSEN_BIN);
@SCRIPT_PATH_PARTS = split('/',$SCRIPT_ABS_PATH);
$PROJECT_NAME = $SCRIPT_PATH_PARTS[-1];

if($SCRIPT_PATH_PARTS[-2] eq 'src')
{
	$OPTIONS_VALUES->{'auto-dev-mode'} = 1;
	$PROJECT_NAME = $SCRIPT_PATH_PARTS[-3];
	@UP_PATH_COMPONENTS=($CHOSEN_BIN,'..');
	$PROJECT_NAME = $SCRIPT_PATH_PARTS[-3];
	$PROJECT_NAME =~ s/_/-/g;
	@POST_PATH_COMPONENTS = ();
}

our $TEMPLATE_DIR;
our $PROJECT_TEMPLATE_DIR;

our $TEMPLATE_CONFIG = {
	ABSOLUTE => 1,
};

my $prompts = {
	project_name => {display => "Project name", required => 1},
	summary => {display => "Short summary", required => 1},
#	install_dir => {display => "Installation dir", required => 1},
	wiki_page => {display => "Wiki page",},
	ticket_url => {display => "Ticket URL",},
};

my $project_info = get_project_info($prompts);

use JSON;
my $json = JSON->new->allow_nonref;

process_project_dir(
	{
		__json_project_data => $json->pretty->encode($project_info),
		project => $project_info
	}
);
exit;


sub get_project_info
{
	my ($prompts) = @_;
	
	my $project_info = {};

	$project_info->{dater} = `date -R`;
	chomp($project_info->{dater});

	while (! defined $project_info->{project_name}
		|| $project_info->{project_name} =~ m/^\d/
		|| $project_info->{project_name} =~ m/\s+/
		|| $project_info->{project_name} =~ m/-/
	)
	{
		print "Project names must not begin with numbers.\n";
		print "Project names must not contain whitespace or dashes.\n";
		print "Example: some_project_name\n";
		get_stuff($project_info, $prompts, 'project_name');
	}
	
	$project_info->{package_name} = $project_info->{project_name};
	$project_info->{package_name} =~ s/_/-/g;
	

	my @project_name_parts = split('_', $project_info->{project_name});
	$project_info->{aspell_name_parts} = join("\n", @project_name_parts);

	get_stuff($project_info, $prompts, 'summary');

	get_stuff($project_info, $prompts, 'wiki_page');
	get_stuff($project_info, $prompts, 'ticket_url');

	$project_info->{package_name} = $project_info->{project_name};
	$project_info->{package_name} =~ s/_/-/g;
	return $project_info;
}

sub get_stuff
{
	my ($hr, $prompts, $field) = @_;
	$hr->{$field} = prompt_and_get($prompts, $field);
	if ($prompts->{$field}->{required} && ! $hr->{$field})
	{
		print STDERR "$field is required.  exiting.",$/;
		exit;
	}
}

sub prompt_and_get
{
	my ($hr, $field) = @_;
	
	print "Required:",$/ if ($hr->{$field}->{required});
	print $hr->{$field}->{display},
		($hr->{$field}->{default} ? ' [' . $hr->{$field}->{default} .']' : '' ),": ";
	my $line = <STDIN>;
	chomp($line);
	$line ||= $hr->{$field}->{default};
	return $line;
}

sub write_template_file
{
	my ($output_file_name, $input_file_name, $template_vars_hr) = @_;
	
	# print "Template HR:", Dumper($template_hr),$/;

	my $template = new Template($TEMPLATE_CONFIG)
		|| die "$Template::ERROR\n";

	$template->process($input_file_name,
		$template_vars_hr,
		$output_file_name,
	) or die $template->error();

}

sub process_project_dir
{
	my ($project_info) = @_;
	use File::Copy::Recursive qw(rcopy);
	
	local $File::Copy::Recursive::KeepMode = 0;
	
	
	
	rcopy($OPTIONS_VALUES->{'source-path'}, $OPTIONS_VALUES->{'dest-path'})
		or die (
			"Unable to rcopy ",
			$OPTIONS_VALUES->{'source-path'},
			" to ",
			$OPTIONS_VALUES->{'dest-path'},
			" : ",
			$!
		);

	debug("Running template routines with data:",$/);
	debug(Dumper($project_info,$/));


	finddepth(
		{
			wanted => sub { rename_path_template($_, $project_info); },
			no_chdir => 1,
		},
		$OPTIONS_VALUES->{'dest-path'},
	);

	use File::Find;

	finddepth(
		{
			no_chdir => 1, 
			wanted => sub {
				my $file = $_;
				# print "Processing: $file\n";
				process_file_template($file, $project_info)
			},
		},
		$OPTIONS_VALUES->{'dest-path'}
	);

}

sub process_file_template
{
	my ($source_file_name, $project_info) = @_;
	my $temp_file_name = File::Temp::tmpnam();

	debug("Processing file template: $source_file_name",$/);
	
	# use Cwd;
	# print "Cwd: ", getcwd,$/;
	# print "Exists!$/" if (-e $source_file_name);
	
	return if (! -f $source_file_name);
	debug("Source file: $source_file_name\n");
	debug("Temp file: $temp_file_name\n");

	use File::Temp;
	use File::Copy;
	
	write_template_file(
		$temp_file_name, 
		$source_file_name,
		$project_info,
	);
	copy($temp_file_name, $source_file_name);
	unlink($temp_file_name);
}

sub rename_path_template
{
	my ($path, $template_data) = @_;

	use File::Basename;
	# print "$path",$/;
	
	my $template = new Template()
		|| die $Template::ERROR,$/;
	
	my $basename = basename($path);
	my $dirname = dirname($path);
	debug("Basename: ", $basename,$/);
	debug("Dirname: ", $dirname,$/);
	
	my $new_basename;
	$template->process(
		\$basename,
		$template_data,
		\$new_basename,
	);
	my $new_file_name = join('/', $dirname, $new_basename);

	debug("New file name: $new_file_name",$/);
	
	rename($path, $new_file_name);
}


sub debug
{
	print @_ if ($DEBUG);
}
