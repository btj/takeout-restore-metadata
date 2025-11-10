#!/usr/bin/perl
use strict;
use warnings;

# Get all .json files in the current directory
my @json_files = glob("*.json");

# These are the unique paths of properties in these JSON files:
# creationTime
# creationTime.formatted
# creationTime.timestamp
# description
# geoData
# geoData.altitude
# geoData.latitude
# geoData.latitudeSpan
# geoData.longitude
# geoData.longitudeSpan
# geoDataExif
# geoDataExif.altitude
# geoDataExif.latitude
# geoDataExif.latitudeSpan
# geoDataExif.longitude
# geoDataExif.longitudeSpan
# googlePhotosOrigin
# googlePhotosOrigin.fromPartnerSharing
# googlePhotosOrigin.mobileUpload
# googlePhotosOrigin.mobileUpload.deviceType
# imageViews
# photoTakenTime
# photoTakenTime.formatted
# photoTakenTime.timestamp
# title
# url

# Here is an example JSON file:

# {
#   "title": "IMG_4345.MOV",
#   "description": "",
#   "imageViews": "34",
#   "creationTime": {
#     "timestamp": "1652004285",
#     "formatted": "May 8, 2022, 10:04:45 AM UTC"
#   },
#   "photoTakenTime": {
#     "timestamp": "1651994997",
#     "formatted": "May 8, 2022, 7:29:57 AM UTC"
#   },
#   "geoData": {
#     "latitude": 50.793,
#     "longitude": 4.935099999999999,
#     "altitude": 46.71,
#     "latitudeSpan": 0.0,
#     "longitudeSpan": 0.0
#   },
#   "geoDataExif": {
#     "latitude": 50.793,
#     "longitude": 4.935099999999999,
#     "altitude": 46.71,
#     "latitudeSpan": 0.0,
#     "longitudeSpan": 0.0
#   },
#   "url": "https://photos.google.com/photo/AF1QipM0W80dCEXkM66us6uOoIlCa-QBAfUiXQlbM0lK",
#   "googlePhotosOrigin": {
#     "mobileUpload": {
#       "deviceType": "IOS_PHONE"
#     }
#   }
# }

# For each of these .json files, parse the file and retrieve the photoTakenTime.timestamp value.
# Also retrieve the media file's modification time from the filesystem.
# If the file's modification time is within 1 day of the photoTakenTime.timestamp, skip the file. (It has already been processed.)
use JSON;
use File::stat;
use Time::Local;
use POSIX qw(strftime);

my $files_processed = 0;
foreach my $json_file (@json_files) {
    $files_processed++;
    print "$files_processed of " . scalar(@json_files) . ": Reading '$json_file'...\n";
    open my $fh, '<', $json_file or die "Could not open '$json_file' $!\n";
    local $/; # Enable 'slurp' mode
    my $json_text = <$fh>;
    close $fh;

    my $data = decode_json($json_text);

    my $photo_taken_timestamp = $data->{photoTakenTime}->{timestamp};
    my $media_file = $data->{title};
    my $file_stat = stat($media_file);
    unless ($file_stat) {
        warn "Could not stat '$media_file': $!\n";
        next;
    }
    my $file_modification_time = $file_stat->mtime;

    # Check if the file's modification time is within 1 day (86400 seconds) of the photoTakenTime.timestamp
    if (abs($file_modification_time - $photo_taken_timestamp) <= 86400) {
        print "Skipping '$json_file': already processed.\n";
        next;
    }

    print "Processing '$json_file': photo taken at $photo_taken_timestamp, file modified at $file_modification_time.\n";
    # First set the photo taken time (and all other times) in EXIF metadata (using exiftool)
    # Note: $photo_taken_timestamp is UTC and EXIF timestamps should be local time (Belgium)
    my $ts = int($photo_taken_timestamp // 0);

    # Convert UTC timestamp to Europe/Brussels local time (respects DST)
    local $ENV{TZ} = 'Europe/Brussels';
    POSIX::tzset();
    my $formatted_time = strftime("%Y:%m:%d %H:%M:%S", localtime($ts));

    # Update EXIF using Image::ExifTool (Perl API)
    require Image::ExifTool;
    my $et = Image::ExifTool->new;
    $et->SetNewValue('AllDates', $formatted_time);
    my $wrote = $et->WriteInfo($media_file);
    unless ($wrote) {
        my $err = $et->GetValue('Error') || $et->GetValue('Warning') || 'unknown error';
        warn "Image::ExifTool write failed for '$media_file': $err\n";
    }
    print "Updated EXIF AllDates to '$formatted_time' for '$media_file'.\n";

    # Set the EXIF geo data. Use geoData if available, otherwise geoDataExif. If either is all zeroes, consider it unavailable.
    my $geo = $data->{geoData};
    my $geo_exif = $data->{geoDataExif};
    if (defined $geo && !($geo->{latitude} == 0 && $geo->{longitude} == 0)) {
        $et->SetNewValue('GPSLatitude', $geo->{latitude});
        $et->SetNewValue('GPSLongitude', $geo->{longitude});
        $et->SetNewValue('GPSAltitude', $geo->{altitude});
        $et->WriteInfo($media_file);
        print "Updated EXIF GPS data from geoData for '$media_file'.\n";
    } elsif (defined $geo_exif && !($geo_exif->{latitude} == 0 && $geo_exif->{longitude} == 0)) {
        $et->SetNewValue('GPSLatitude', $geo_exif->{latitude});
        $et->SetNewValue('GPSLongitude', $geo_exif->{longitude});
        $et->SetNewValue('GPSAltitude', $geo_exif->{altitude});
        $et->WriteInfo($media_file);
        print "Updated EXIF GPS data from geoDataExif for '$media_file'.\n";
    }

}
