%% s_L3_rgbir
%
%  Simulate and evaluate an RGB-IR camera with 2x2 color filter array
%
% 
% HJ, VISTA TEAM, 2016

%% Init
% init ISET session
ieInit;

% init parameters
cfa = [2 1; 3 4];
patchSz = [5 5];
padSz = (patchSz-1)/2;
nTrain = 1; % train on first image and test on the second one
expFrac = 0.1:0.1:1;
wave = 420:10:950;
pixelSz = 2.75e-6;

% list all RGB-NIR images
s = dir('../Data/NIR/*.mat');

%% Create L3 data structure
% load rgb-ir camera model
camera = cameraCreate;
camera = cameraSet(camera, 'oi wave', wave);
camera = cameraSet(camera, 'sensor wave', wave);
camera = cameraSet(camera, 'sensor cfa pattern', cfa);
fspec  = ieReadSpectra('rgbIR_spd.mat', wave);
camera = cameraSet(camera, 'sensor filter spectra', fspec);
camera = cameraSet(camera, 'sensor ir filter', ones(length(wave), 1));
camera = cameraSet(camera, 'pixel spectral qe', ones(length(wave), 1));
camera = cameraSet(camera, 'sensor filter name', ...
                     {'red', 'green', 'blue', 'ir'});
camera = cameraSet(camera, 'pixel size constant fill factor', pixelSz);

% load rgb-ir scenes
scenes = cell(nTrain+1, 1);
for ii = 1 : nTrain + 1
    sceneS = load(s(ii).name);
    scenes{ii} = sceneFromBasis(sceneS);
    scenes{ii} = sceneSet(scenes{ii}, 'wave', wave);
end

% create l3 data structure
% In some cases, we might want to turn off the noise
% camera = cameraSet(camera, 'sensor noise flag', 0);
l3d = l3DataSimulation('camera', camera, 'expFrac', expFrac, 'sources', scenes);
[raw, xyz] = l3d.dataGet(nTrain+1); % the extra 1 is for testing

%% Learn local linear kernels
l3t = l3TrainRidge();
l3t.l3c.patchSize = patchSz;
l3t.l3c.cutPoints = {logspace(-2.5, -.5, 40), []};
trainIndx = 1:nTrain*length(l3d.expFrac);
l3t.train(l3DataCamera(raw(trainIndx), xyz(trainIndx), cfa));

%% Plot
%  plot center pixel weight of green towards the output red channel as a
%  function of response level
cPixelType = 1; % green
indx = l3t.l3c.query('pixelType', cPixelType);
k = cat(3, l3t.kernels{indx});
k = k(2:end, :, :);
k = bsxfun(@rdivide, abs(k), sum(abs(k)));
k = reshape(k(13, :, :), l3t.nChannelOut, [])';
respLev = l3t.l3c.classCenters{1};
respLev(1) = 0;
respLev(end) = cameraGet(camera, 'sensor voltage swing');
vcNewGraphWin; plot(respLev, k);
xlabel('Mean response level'); ylabel('Normalized center pixel weight');

%  plot the total weight of white pixel as a function of response level
wWeight = zeros(l3t.l3c.nLabels, l3t.nChannelOut);
for ii = cPixelType : l3t.l3c.nPixelTypes : l3t.l3c.nLabels
    curCFA = l3t.l3c.getClassCFA(ii);
    curK = l3t.kernels{ii}(2:end, :);
    wWeight(ii, :) = sum(abs(curK(curCFA==4, :))) ./ sum(abs(curK));
end
vcNewGraphWin; plot(respLev, wWeight(cPixelType:l3t.l3c.nPixelTypes:end, :));