function [ features ] = compute_lbp( imgs, index, indexValue, orientation, para ,fType )
%COMPUTE_LBP Summary of this function goes here
%   Detailed explanation goes here

% image preprocess
imgsTemp = double(imgs)/255;	% 0~255 -> 0~1
for l=1:size(imgsTemp,4)
	if strcmp(para.(fType).color_mode, 'RGB')
		temp(:,:,:,l) = imgsTemp(:,:,:,l);
	elseif strcmp(para.(fType).color_mode, 'RGI')
		temp(:,:,:,l) = my_rgb2rgi(imgsTemp(:,:,:,l));
	elseif strcmp(para.(fType).color_mode, 'HSV')
		temp(:,:,:,l) = rgb2hsv(imgsTemp(:,:,:,l));
	end
	
	if para.(fType).histeq
		for i=para.(fType).histeq
			temp(:,:,i,l) = histeq(temp(:,:,i,l));
		end
	end
end
imgsTemp = temp;

% for LBP
RotateIndex = para.lbp.RotateIndex;
TInterval = para.lbp.TInterval;
TimeLength = para.lbp.TimeLength;
BorderLength = para.lbp.BorderLength;
bBilinearInterpolation = para.lbp.bBilinearInterpolation;
Type = para.lbp.Type;	% 'VLBP' or 'LBPTOP'

% for 'VLBP' only
FRadius = para.lbp.FRadius;
NeighborPointsV = para.lbp.NeighborPointsV;

% for 'LBPTOP' only
FxRadius = para.lbp.FxRadius;
FyRadius = para.lbp.FyRadius;
Bincount = para.lbp.Bincount;	% 59 or 0
NeighborPointsL = para.lbp.NeighborPointsL;
Code = para.lbp.Code;

adaptivemode = para.adaptivemode;
l_num = para.(fType).l_num;
channels = para.(fType).channels;
threshold = para.of.indexThresholdValue;
if ~adaptivemode
	L = para.(fType).L;
	ldelta = floor(2*L/l_num);
else
	patches = para.(fType).l_all;
	patchN = patches/l_num;
end
if para.(fType).usePart_pos
	part_pos = para.part_pos;
	num_part = para.num_part;
else
	part_pos = my_patchGen(para.window_size,...
		para.(fType).h_num,para.(fType).w_num,para.(fType).h_overlap,para.(fType).w_overlap);
	num_part = size(part_pos,2);
end

features = [];
features.feature{1} = [];
features.index = [];
features.indexEnd = [];
features.fragSign = [];
features.fragOrie = [];

ii = 1;
if ~adaptivemode
	startIndex = abs(index);
else
	switch adaptivemode
		case {1, 4}	% 每个极值取视频段
			start = 1;
			startIndex = start:1:length(index)-patches;	% +1-1
		case 2	% 每个谷值取视频段
			start = (sign(index(1))+3)/2;
			startIndex = start:2:length(index)-patches;
		case 3	% 每个峰值取视频段
			start = (-sign(index(1))+3)/2;
			startIndex = start:2:length(index)-patches;
	end
end

for i = startIndex
	if ~adaptivemode
        if size(imgsTemp,4)<2*L; continue; end
		if i<=L
			imgSeq = imgsTemp(:,:,:,1:2*L);
			fragIdx = 1;
		elseif i>=size(imgsTemp,4)-L+1
			imgSeq = imgsTemp(:,:,:,end-2*L+1:end);
			fragIdx = size(imgsTemp,4)-2*L+1;
		else
			imgSeq = imgsTemp(:,:,:,i-L:i+L-1);
			fragIdx = i-L;
		end
		fragIdxEnd = fragIdx+2*L-1;
		fragSign = 1;
		
	else
		if ~isempty(indexValue)
			if indexValue(patches,i) < threshold
				continue;
			end
		end
		
		temporal = abs(index(i:i+patches));
		imgSeq = imgsTemp(:,:,:,temporal(1):temporal(end)-1);
		sizeL = temporal-temporal(1)+1;
		fragIdx = temporal(1);
		fragIdxEnd = temporal(end)-1;
		fragSign = sign(index(i));
	end
	
	desc = [];
	for c = channels
		
		descPart = [];
		for j = 1:num_part
			part_yindex = part_pos(2,j):part_pos(4,j);
			part_xindex = part_pos(1,j):part_pos(3,j);
			
			for k = 1:l_num
				if ~adaptivemode
					part_zindex = (k-1)*ldelta+1 : k*ldelta;
				else
					zstarti = (k-1)*patchN+1;
					zendi = k*patchN+1;
					zstart = floor(linear_interpolation(zstarti, sizeL(floor(zstarti)), sizeL(ceil(zstarti))));
					zend = floor(linear_interpolation(zendi, sizeL(floor(zendi)), sizeL(ceil(zendi))));
					part_zindex = zstart:zend-1;
				end
				imgSeqPart = imgSeq(part_yindex,part_xindex,c,part_zindex);
				
				if strcmp(Type, 'VLBP')
					descTemp = my_RIVLBP(imgSeqPart, TInterval, FRadius, NeighborPointsV, BorderLength, TimeLength, RotateIndex, bBilinearInterpolation);
				elseif strcmp(Type, 'LBPTOP')
					descTemp = my_LBPTOP(imgSeqPart, FxRadius, FyRadius, TInterval, NeighborPointsL, TimeLength, BorderLength, bBilinearInterpolation, Bincount, Code);
				end
				
				descPart = [descPart; descTemp(:)];		% 177*2*9 = 3186
			end
		end
		desc = [desc; descPart(:)];	% 3186*1 = 3186
	end	% for c
	features.feature{ii} = desc(:);
	features.index(ii) = fragIdx;
	features.indexEnd(ii) = fragIdxEnd;
	features.fragSign(ii) = fragSign;
	features.fragOrie(ii) = sign(mean(orientation));
% 	progress('Hog3d', ii, length(index));
	features.hasstartIndex = true;
	ii = ii+1;
end

if ~isfield(features,'hasstartIndex')
	features.hasstartIndex = false;
end

end

