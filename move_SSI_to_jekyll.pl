#!/usr/bin/env perl
use strict;
use warnings;
use File::Find;
use File::Path qw(make_path);
use File::Copy;
use File::Basename;

# Configuration
my $source_dir = $ARGV[0] || die "Usage: $0 <source_directory>\n";
my $repo_root = dirname($source_dir);
my $includes_dir = "$repo_root/_includes";

# Create _includes directory
make_path($includes_dir) unless -d $includes_dir;

# Track which include files we've already moved
my %moved_includes;

# Find all HTML files
my @html_files;
find(sub {
    push @html_files, $File::Find::name if /\.html$/;
}, $source_dir);

print "Found " . scalar(@html_files) . " HTML files to process\n";

# First pass: identify and move all include files
print "\n=== PHASE 1: Moving include files to _includes/ ===\n";
foreach my $html_file (@html_files) {
    open(my $fh, '<', $html_file) or die "Can't open $html_file: $!";
    my $content = do { local $/; <$fh> };
    close($fh);
    
    # Find all SSI includes in this file
    while ($content =~ /<!--#include virtual="([^"]+)"\s*-->/g) {
        my $include_path = $1;
        next if $moved_includes{$include_path}; # Already processed
        
        # Resolve the include path relative to the HTML file
        my $html_dir = dirname($html_file);
        my $full_include_path;
        
        if ($include_path =~ m{^/}) {
            # Absolute path from root
            $full_include_path = "$source_dir$include_path";
        } else {
            # Relative path
            $full_include_path = "$html_dir/$include_path";
        }
        
        # Normalize the path
        $full_include_path =~ s{/\./}{/}g;
        while ($full_include_path =~ s{/[^/]+/\.\./}{/}) {}
        
        if (-f $full_include_path) {
            # Determine new filename (convert .txt to .html, keep .html as is)
            my $include_basename = basename($include_path);
            $include_basename =~ s/\.txt$/.html/;
            
            my $new_include_path = "$includes_dir/$include_basename";
            
            unless (-f $new_include_path) {
                copy($full_include_path, $new_include_path) or warn "Can't copy $full_include_path to $new_include_path: $!";
                print "  Moved: $include_path -> _includes/$include_basename\n";
            }
            
            $moved_includes{$include_path} = $include_basename;
        } else {
            print "  WARNING: Include file not found: $full_include_path (referenced in $html_file)\n";
            $moved_includes{$include_path} = basename($include_path);
        }
    }
}

# Second pass: Update all HTML files
print "\n=== PHASE 2: Converting HTML files ===\n";
foreach my $html_file (@html_files) {
    open(my $fh, '<', $html_file) or die "Can't open $html_file: $!";
    my $content = do { local $/; <$fh> };
    close($fh);
    
    my $original_content = $content;
    my $changes = 0;
    
    # Add front matter if not present
    unless ($content =~ /^---\n/) {
        $content = "---\n---\n" . $content;
        $changes++;
    }
    
    # Replace all SSI includes with Jekyll includes
    $content =~ s{<!--#include virtual="([^"]+)"\s*-->}{
        my $include_path = $1;
        my $include_file = $moved_includes{$include_path} || do {
            my $base = basename($include_path);
            $base =~ s/\.txt$/.html/;
            $base;
        };
        $changes++;
        "{% include $include_file %}";
    }ge;
    
    # Only write if changes were made
    if ($changes > 0) {
        open(my $out, '>', $html_file) or die "Can't write to $html_file: $!";
        print $out $content;
        close($out);
        print "  Updated: $html_file ($changes changes)\n";
    }
}

# Create _config.yml
print "\n=== PHASE 3: Creating _config.yml ===\n";
my $config_file = "$repo_root/_config.yml";
unless (-f $config_file) {
    open(my $config, '>', $config_file) or die "Can't create $config_file: $!";
    print $config "# Jekyll configuration\n";
    print $config "source: " . basename($source_dir) . "\n";
    print $config "exclude:\n";
    print $config "  - README.md\n";
    print $config "  - convert_to_jekyll.pl\n";
    close($config);
    print "  Created: _config.yml\n";
} else {
    print "  _config.yml already exists, skipping\n";
}

print "\n=== CONVERSION COMPLETE ===\n";
print "Total HTML files processed: " . scalar(@html_files) . "\n";
print "Include files moved: " . scalar(keys %moved_includes) . "\n";
