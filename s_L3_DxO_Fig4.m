%% L3 reproduce effects of DxO pipeline
%    The figure is used as figure 4
%
%
% addpath(genpath('~/github/L3'));
% addpath(genpath('~/github/L3reverse'));
%
%  HJ, VISTA TEAM, 2016

%% Initialization
% Init ISET session
ieInit;

% Init camera parameters
cfa = [2 1; 3 4];  % Bayer pattern, 2 and 4 are both for green
patch_sz = [5 5];
pad_sz   = (patch_sz - 1) / 2;

%% Load a pair of raw and rendered file
%  load rgb file
raw_name = 'ma_griz_39558';
tif_name = [lower(raw_name) '_dxo_nodist.tif'];

% load image
% tif = im2double(rd.readArtifact(tif_name, 'type', 'tif'));
tif = im2double(imread(tif_name));
if isodd(size(tif, 1)), tif = tif(1:end-1, :, :); end
if isodd(size(tif, 2)), tif = tif(:, 1:end-1, :); end

sz = [size(tif, 1) size(tif, 2)];

% Offset for Cardinal, D600
if sz(1) > sz(2) % vertical
    offset = [24 1];
else % horizontal
    offset = [1 -23];
end

% load raw image
% raw = im2double(rd.readArtifact(raw_name, 'type', 'pgm'));
raw = im2double(imread([raw_name '.pgm']));
raw = rawAdjustSize(raw, sz, pad_sz, offset);

%% Learn l3 kernels
l3t = l3TrainRidge();
l3t.l3c.patchSize = patch_sz;
l3t.l3c.statFunc = {@imagePatchMean};
l3t.l3c.statFuncParam = {{}};
l3t.l3c.statNames = {'mean'};
l3t.l3c.cutPoints = {logspace(-3.5, -1.6, 40)};

% learn linear filters
l3t.train(l3DataCamera({raw}, {tif}, cfa));

%% Render the image
% Render
l3r = l3Render();
l3_RGB = ieClip(l3r.render(raw, cfa, l3t), 0, 1);
vcNewGraphWin([], 'wide');
subplot(1, 2, 1); imshow(tif); title('Nikon D600');
subplot(1, 2, 2); imshow(l3_RGB); title('L3 Rendered');

%% Comptue S-CIELAB difference
% Init parameters
d = displayCreate('LCD-Apple');
d = displaySet(d, 'gamma', 'linear');  % use a linear gamma table
d = displaySet(d, 'viewing distance', 1);
rgb2xyz = displayGet(d, 'rgb2xyz');
wp = displayGet(d, 'white xyz'); % white point
params = scParams;
params.sampPerDeg = displayGet(d, 'dots per deg');

% Compute difference
xyz1 = imageLinearTransform(l3_RGB, rgb2xyz);
xyz2 = imageLinearTransform(tif, rgb2xyz);
de = scielab(xyz1, xyz2, wp, params);
vcNewGraphWin; imagesc(de, [0 7]); axis image; axis off; colorbar;
vcNewGraphWin; hist(de(:), 100);
fprintf('Mean S-CIELab DeltaE is: %.3f\n', mean(de(:)));
fprintf('Std of S-CIELab DeltaE is: %.3f\n', std(de(:)));

%%