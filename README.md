# Restore media data downloaded from Google Takeout

For each `.json` file in the current directory, performs the following modifications to the media file specified in the `.json` file's `title` property:
- If the `.json` file specifies geo data, sets the media file's geo data 
- Sets all of the media file's dates (filesystem modification date, filesystem creation date, EXIF creation date, ...) to the "photo taken at" date specified in the `.json` file

## How to use

1. Install Perl
2. Install [exiftool](https://exiftool.org)
3. Set `PERL5LIB` to point to the Perl library included with `exiftool`
4. `cd dir_with_json_files` and run the script
