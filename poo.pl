#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Std;

my $is_verbose = 0;
my $is_commit = 0;

#Main block
{
    my $usage = "poo [-i (dir) input] [-o (dir) output] [-c commit] [-v verbose]";
    my %options = ();
    getopts("i:o:cv", \%options) or die $usage;
    my $input = $options{i};
    my $output = $options{o};
    $is_commit = $options{c};
    $is_verbose = $options{v};
    my $dup_count = 0;

    my @exif_infos = build_exif_infos($input);
    foreach my $exif_info (@exif_infos) {
        if ($is_verbose) { print($exif_info->to_string() . "\n"); }
        my $dir = mkdir_if_missing($output, $exif_info);
        $dup_count += mv_photo($exif_info->get_directory(), $exif_info->get_filename(), $dir);
    }
    if ($dup_count) { print("Duplicates found: $dup_count\n"); }
    exit 0;
}

#------------------------------------------------------------------------------
sub build_exif_infos
{
    my ($input) = @_;
    my @details = ();
    my $cmd = 'exiftool -r -p \'$Directory,$FileName,$Make,$Model,$CreateDate\' -d %Y%m%d:%H%M%S ' . $input . ' 2>/dev/null';
    if ($is_verbose) { print("$cmd\n"); }
    my $stdout = `$cmd`;
    my $sc = $?;
    if ($sc) {
        die "Exited with status " . ($sc >> 8) . "\nCMD: \"$cmd\"";
    }
    chomp $stdout;
    my @lines = split("\n", $stdout);
    foreach my $line (@lines) {
        chomp $line;
        push(@details, new ExifInfo(split(",", $line)));
    }
    return @details;
}

#------------------------------------------------------------------------------
sub mkdir_if_missing
{
    my ($output, $exif_info) = @_;
    my $dir = $output . "/" .
        $exif_info->get_make() . "." . $exif_info->get_model() . "/" .
        $exif_info->get_creation_year() . "/" .
        $exif_info->get_creation_month() . "/" .
        $exif_info->get_creation_date();
    my $cmd = "mkdir -p $dir";
    if ($is_verbose) { print("$cmd\n"); }
    if (!$is_commit) { return $dir; }
    my $stdout = `$cmd`;
    my $sc = $?;
    if ($sc) {
        die "Exited with status " . ($sc >> 8) . "\nCMD: \"$cmd\"";
    }
    return $dir;
}

#------------------------------------------------------------------------------
sub mv_photo
{
    my ($input, $filename, $dir) = @_;

    if (-e "$dir/$filename") {
        print("Will not move $input/$filename to $dir/$filename: destination exists\n");
        return 1;
    }

    my $cmd = "mv -n $input/$filename $dir";
    if ($is_verbose) { print("$cmd\n"); }
    if (!$is_commit) { return 0; }
    my $stdout = `$cmd`;
    my $sc = $?;
    if ($sc) {
        die "Exited with status " . ($sc >> 8) . "\nCMD: \"$cmd\"";
    }
    return 0;
}

###############################################################################
{
    package ExifInfo;
    sub new
    {
        my ($class, $directory, $filename, $make, $model, $creation_date_time) = @_;
        my $creation_date;
        my $creation_time;

        if ($creation_date_time =~ /^([0-9]{8}):([0-9]{6})$/) {
            $creation_date = substr($creation_date_time, 0, 8);
            $creation_time = substr($creation_date_time, 10, 16);
        } else {
            die "Unexpected creation date/time format: $creation_date_time";
        }

        #Replace spaces with underscores
        $make =~ s/\ /_/g;
        $model =~ s/\ /_/g;

        my $self = {
            directory => $directory,
            filename => $filename,
            make => $make,
            model => $model,
            creation_date => $creation_date,
            creation_time => $creation_time
        };

        bless($self, $class);
        return $self;
    }
    sub get_directory
    {
        my ($self) = @_;
        return $self->{directory};
    }
    sub get_filename
    {
        my ($self) = @_;
        return $self->{filename};
    }
    sub get_make
    {
        my ($self) = @_;
        return $self->{make};
    }
    sub get_model
    {
        my ($self) = @_;
        return $self->{model};
    }
    sub get_creation_date
    {
        my ($self) = @_;
        return $self->{creation_date};
    }
    sub get_creation_time
    {
        my ($self) = @_;
        return $self->{creation_time};
    }
    sub get_creation_year
    {
        my ($self) = @_;
        return substr($self->get_creation_date(), 0, 4);
    }
    sub get_creation_month
    {
        my ($self) = @_;
        return substr($self->get_creation_date(), 4, 2);
    }
    sub to_string
    {
        my ($self) = @_;
        return "ExifInfo:\n" .
            "Directory: " . $self->get_directory() . "\n" .
            "File name: " . $self->get_filename() . "\n" .
            "Make: " . $self->get_make() . "\n" .
            "Model: " . $self->get_model() . "\n" .
            "Creation date: " . $self->get_creation_date() . "\n" .
            "Creation time: " . $self->get_creation_time() . "\n" .
            "Creation year: " . $self->get_creation_year() . "\n" .
            "Creation month: " . $self->get_creation_month() . "\n";
    }
}
