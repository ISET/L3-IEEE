%% s_L3_PatchSize
%
%   This script shows the effect of different patch size on the rendering
%   performance
%
% HJ, VISTA TEAM, 2016

%% Init
% init ISET session
ieInit;

% init parameters
cfa = [2 1; 3 2];
p_max = 1000; % max number of patches per class per image
patch_sz_list = [5 7 9];

% there are two groups of images (cfa alignment is different) on the
% server. we pick out one group from them
indx = [2 4 5 7:10 12:14 21:29 33:35];

% init remote data toolbox client
s = dir('../Data/Nikon/*.pgm');

% init parameters for SCIELAB
d = displayCreate('LCD-Apple');
d = displaySet(d, 'gamma', 'linear');  % use a linear gamma table
d = displaySet(d, 'viewing distance', 1);

rgb2xyz = displayGet(d, 'rgb2xyz');
wp = displayGet(d, 'white xyz'); % white point
params = scParams;
params.sampPerDeg = displayGet(d, 'dots per deg');

%% Training and rendering
%  We use all the odd-numbered images for training
l3t_list = cell(length(patch_sz_list), 1);
psnr_val = zeros(length(s), length(patch_sz_list));
de = zeros(length(s), length(patch_sz_list));
    
for kk = 1 : length(patch_sz_list)
    patch_sz = [patch_sz_list(kk) patch_sz_list(kk)];
    pad_sz = (patch_sz - 1) / 2;
    
    l3t = l3TrainRidge();
    l3t.l3c.patchSize = patch_sz;
    l3t.l3c.p_max = p_max;
    l3t.l3c.statFunc = {@imagePatchMean};
    l3t.l3c.statFuncParam = {{}};
    l3t.l3c.statNames = {'mean'};
    l3t.l3c.cutPoints = {logspace(-3.5, -1.6, 40)};
    
    for ii = 1 : 2 : length(s)
        % load data
        img_name = s(ii).name(1:end-4);
        raw = im2double(imread([img_name '.pgm']));
        rgb = im2double(imread([img_name '.jpg']));
        
        % classify
        l3t.l3c.classify(l3DataCamera({raw}, {rgb}, cfa));
    end
    
    % learn transforms
    l3t.train();
    l3t.l3c.clearData();
    l3t_list = l3t.copy();
    
    % Rendering
    %  We render all the images and record the PSNR and SCIELAB
    l3r = l3Render();
    for ii = 1 : length(s)
        % load data
        img_name = s(ii).name(1:end-4);
        raw = im2double(imread([img_name '.pgm']));
        rgb = im2double(imread([img_name '.jpg']));
        rgb = rgb(pad_sz(1)+1:end-pad_sz(1), pad_sz(2)+1:end-pad_sz(2), :);
        
        % render the image with L3
        l3_RGB = ieClip(l3r.render(raw, cfa, l3t), 0, 1);
        
        % compute PSNR
        psnr_val(ii, kk) = psnr(l3_RGB, rgb);
        
        % compute S-CIELAB DeltaE
        xyz1 = imageLinearTransform(l3_RGB, rgb2xyz);
        xyz2 = imageLinearTransform(rgb, rgb2xyz);
        de_img = scielab(xyz1, xyz2, wp, params);
        de(ii, kk) = mean(de_img(:));
    end
end

%% Plot
vcNewGraphWin;
boxplot(de, 'labels', {'5x5', '7x7', '9x9'});
hold on; plot(1:length(patch_sz_list), de, '.g');
xlabel('Patch size'); ylabel('S-CIELAB \DeltaE'); grid on;