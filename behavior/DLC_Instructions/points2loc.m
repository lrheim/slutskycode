function [mass_loc] = points2loc(labels_file,nMice,exclude_parts,p_cutoff)
% Takes deeplabcut output CSV file, output the center of mass in each frame.
% INPUTS:
%       labels_file - Either string, the path to the CSV file, or struct
%                     with the raw data in each field, as generated by
%                     "read_label_file":
%                       labels_pos  - double 4d matrix. Position of each
%                                     bodypart in each frame. 
%                                     Ordered: frame X mouse X body part X (x,y,likelihood) 
%                       body_parts  - cellstr, body parts names, order
%                                     matching labels_pos 3rd dimension.
%       nMice       - Number of mice in video. Must be positive interger.
%                     If empty, takes all mice found in the file.
%       exclude_parts
%                   - Text vector, Body parts to exclude when calculating
%                     center of mass.
%       p_cutoff    - scalar between 0 & 1. Minimal likelihood of body
%                     parts to include in center of mass.
% OUTPUT:
%       mass_loc    - double nFrames X iMouse X 1 (mass center label) X 2 (x,y),
%                     location of center of mass.
%
%

arguments
    labels_file (1,1)
    nMice double {mustBePositive,mustBeScalarOrEmpty} = [];
    exclude_parts (:,1) string {mustBeText} = ""
    p_cutoff double {mustBeInRange(p_cutoff,0,1)} = 0
end

% get data
if isstruct(labels_file)
    labels_pos = labels_file.labels_pos;
    body_parts = labels_file.body_parts;
elseif (isstring(labels_file) || ischar(labels_file)) && isfile(labels_file)
    [labels_pos,body_parts] = read_label_file(labels_file);
else
    error('First input, "labels_file", must be file name of DLC output CSV, or the already read data from such a file ("read_label_file" output)')
end

% remove extra mice
if isempty(nMice)
    nMice = size(labels_pos,2);
end
labels_pos = labels_pos(:,1:nMice,:,:);

% remove low likelihood points
if size(labels_pos,4) == 3
    labels_pos(repmat(labels_pos(:,:,:,3) < p_cutoff,[1,1,1,3])) = nan;
end

% remove excluded body parts
labels_pos(:,:,ismember(body_parts,exclude_parts),:) = [];

% calculate center of mass
mass_loc =  mean(labels_pos(:,:,:,1:2),3,"omitnan");

end
