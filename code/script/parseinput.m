function s=parseinput(input,docFile)
%PARSEINPUT Parse input section of a DBAT XML file.
%
%    S=PARSEINPUT(INPUT) parses the input XML block INPUT from a
%    DBAT XML script file. The result is returned in the DBAT
%    structure S.
%
%    INPUT must contain the fields 'cameras', 'images',
%    'image_pts' and may contain the fields 'Attributes','
%    'ctrl_pts', 'check_pts'.
%
%See also: EMPTYDBATSTRUCT, PROB2DBATSTRUCT.

narginchk(2,2);

inputFields={'Attributes','ctrl_pts','check_pts','images','image_pts','cameras','c'};
[ok,msg]=checkxmlfields(input,inputFields,[false,false,false,true,true,true,false]);
if ~ok, error('DBAT XML script input error: %s',msg); end

% Check if a base directory was specified.
[baseDir,rawBaseDir]=getattrbasedir(input,docFile);

% Warn if base dir does not exist.
if ~isempty(baseDir) && ~exist(baseDir,'dir')
    warning('Base directory %s (%s) does not exist!',baseDir, ...
            rawBaseDir);
end

% Parse cameras.
cams=parsecameras(input.cameras,baseDir);

% Parse images.
ims=parseimages(input.images,baseDir);

% Parse image points.
pts=parseimagepts(input.image_pts,baseDir);

% Load control and check points, if any.
ctrlPts=struct('id',zeros(1,0));
if isfield(input,'ctrl_pts')
    ctrlPts=parsectrlpts(input.ctrl_pts,baseDir);
end

checkPts=struct('id',zeros(1,0));
if isfield(input,'check_pts')
    checkPts=parsectrlpts(input.check_pts,baseDir);
end

% Number of images.
nImages=length(ims.id);

% Number of mark points.
nMarkPts=length(pts.id);

% Number of object points.
nOP=length(unique([pts.id,ctrlPts.id,checkPts.id]));

s=emptydbatstruct(nImages,nOP,nMarkPts);

s.zz.cams=cams;
s.zz.ims=ims;
s.zz.pts=pts;
s.zz.ctrlPts=ctrlPts;
s.zz.checkPts=checkPts;