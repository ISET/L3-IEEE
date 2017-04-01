%% s_L3_DataDownload
%
%   This script download and zip the data files
%
% HJ, VISTA TEAM, 2016

%% Init
% init ISET session
ieInit;

%% Download Nikon files
% there are two groups of images (cfa alignment is different) on the
% server. we pick out one group from them
indx = [2 4 5 7:10 12:14 21:29 33:35];

% init remote data toolbox client
rd = RdtClient('scien');
rd.crp('/L3/Farrell/D200/garden');
s = rd.searchArtifacts('dsc_', 'type', 'pgm');
s = s(indx);

for ii = 1 : length(s)
    % download data
    fname = s(ii).artifactId;
    rd.readArtifact(fname, 'type', 'pgm', 'destinationFolder', 'Nikon');
    rd.readArtifact(fname, 'type', 'jpg', 'destinationFolder', 'Nikon');
end

%% Download DxO data
rd.crp('/L3/Cardinal/D600');
raw_name = 'ma_griz_39558';
tif_name = [lower(raw_name) '_dxo_nodist'];
rd.readArtifact(tif_name, 'type', 'tif', 'destinationFolder', 'DxO');
rd.readArtifact(raw_name, 'type', 'pgm', 'destinationFolder', 'DxO');


%% Download human faces data
rd.crp('/L3/faces');
rd.readArtifacts(rd.pwrp, 'destinationFolder', 'Faces');

%% Download near infrared scene data
rd = RdtClient('isetbio');
rd.crp('/resources/scenes/hyperspectral/stanford_database');
s = rd.listArtifacts;

% download the first 7 fruit images
rd.readArtifacts(s(2:8), 'destinationFolder', 'NIR');

%% Zip downloaded files
zip('Data.zip', {'Nikon', 'DxO', 'Faces', 'NIR'});

%% Cleanup
rmdir('Nikon', 's');
rmdir('DxO', 's');
rmdir('Faces', 's');
rmdir('NIR', 's');