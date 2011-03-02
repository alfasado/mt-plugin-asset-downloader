#!/usr/bin/perl -w
use strict;
use lib $ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : 'lib';
use lib $ENV{MT_HOME} ? "$ENV{MT_HOME}/plugins/AssetDownloader/lib" : 'plugins/AssetDownloader/lib';
use MT::Bootstrap App => 'MT::App::CMS::AssetDownloader';
