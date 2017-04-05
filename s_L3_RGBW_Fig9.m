%% s_L3_RGBW_Fig9
%
%  Simulate and evaluate an RGBW camera with 2x2 color filter array
%
% 
% HJ, VISTA TEAM, 2016

%% Init
ieInit;
cfa = [2 1; 3 4];
patchSz = [5 5];
nTrain = 4;
expFrac = [0.1:0.2:0.9 1.2 1.5];

%% Create RGBW camera
% create rgbw camera with 2x2 color filter array
load rgbcCamera.mat  % this is the standard 8x8 rgbc model from omv
camera = cameraSet(camera, 'sensor cfa pattern', cfa);

% scale RGB spectra
fspec = cameraGet(camera, 'sensor filter spectra');
camera = cameraSet(camera, 'sensor filter spectra', fspec);

%% create l3 data structure
l3d = l3DataSimulation('camera', camera, 'expFrac', expFrac);
s = dir('../Data/CISET/*.mat');
for ii = 1 : nTrain+1
    data = load(s(ii).name);
    l3d.sources = cat(1, l3d.sources, data.oi);
end

for ii = 1 : nTrain+1
    l3d.sources{ii} = oiSet(l3d.sources{ii}, 'optics f length', 0.004);
    l3d.sources{ii} = oiSet(l3d.sources{ii}, 'optics f number', 4);
end
[raw, xyz] = l3d.dataGet(nTrain);

%% Learn local linear kernels
l3t = l3TrainRidge();
l3t.l3c.patchSize = patchSz;

min_cut = log10(10 * cameraGet(camera, 'sensor conversion gain'));
max_cut = log10(0.98 * cameraGet(camera, 'sensor voltage swing'));
l3t.l3c.cutPoints = {logspace(min_cut, max_cut, 40), []}; 

trainIndx = 1:nTrain*length(l3d.expFrac);
l3t.train(l3DataCamera(raw(trainIndx), xyz(trainIndx), cfa));

%% Plot
%  visualize the learned transforms
l3t.symmetricKernels;
l3t.plot('kernel image', 1, [], true);
l3t.plot('kernel image', 21, [], true);
l3t.plot('kernel image', 121, [], true);

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
vcNewGraphWin; plot(respLev, k, 'lineWidth', 2);
xlabel('Mean response level'); ylabel('Normalized center pixel weight');

%  plot percentage of saturated pixels
ax = gca; ax_pos = ax.Position;
new_ax = axes('Position', ax.Position, ...
    'XAxisLocation', 'top', ...
    'YAxisLocation', 'right', ...
    'Color', 'none');

threshold = 0.95 * cameraGet(camera, 'pixel voltage swing');
sat_pixels = zeros(l3t.l3c.nLabels/l3t.l3c.nPixelTypes, 4);
tot_pixels = zeros(l3t.l3c.nLabels/l3t.l3c.nPixelTypes, 4);
indx = 1;
for ii = cPixelType : l3t.l3c.nPixelTypes : l3t.l3c.nLabels
    pattern = l3t.l3c.getClassCFA(ii);
    for cc = 1 : 4 % input channel
        data = l3t.l3c.p_data{ii}(pattern == cc, :);
        sat_pixels(indx, cc) = sum(data(:) > threshold);
        tot_pixels(indx, cc) = numel(data);
    end
    indx = indx + 1;
end
plot(respLev, sat_pixels ./ tot_pixels, 'Parent', new_ax);
