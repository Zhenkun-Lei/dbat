function [rr,s0,prob]=romabundledemo_imagevariant(damping,doPause)
%ROMABUNDLEDEMO_IMAGEVARIANT Bundle demo for DBAT, imagevariant self-cal version.
%
%   ROMABUNDLEDEMO_IMAGEVARIANT runs the bundle on the PhotoModeler
%   export file of the ROMA data set with self calibration. In the
%   self-calibation, the principal point is image-variant where as the
%   other IO parameters are block-invariant.
%
%See also: ROMABUNDLEDEMO

if nargin<1, damping='gna'; end

if nargin<2, doPause='on'; end

switch damping
  case {'none','gm','gna','lm','lmp'}
    % Do nothing.
  otherwise
    error('Bad damping');
end

% Extract name of current directory.
curDir=fileparts(mfilename('fullpath'));

% Base dir with input files.
inputDir=fullfile(curDir,'data','dbat');

% PhotoModeler text export file and report file.
inputFile=fullfile(inputDir,'pmexports','roma-pmexport.txt');
% Report file name.
reportFile=fullfile(inputDir,'dbatexports','roma-dbatreport-imagevariant.txt');;

fprintf('Loading data file %s...',inputFile);
prob=loadpm(inputFile);
probRaw=prob;
if any(isnan(cat(2,prob.images.imSz)))
    error('Image sizes unknown!');
end
disp('done.')

% Convert loaded PhotoModeler data to DBAT struct.
s0=prob2dbatstruct(prob);
ss0=s0;

% Estimate f, pp, aspect and lens distortion parameters.
s0.IO.val=s0.IO.prior.val;
s0.bundle.est.IO(repmat(~ismember((1:10)',5),1,size(s0.IO.val,2)))=true;

% Default distortion model is now 3: With aspect/skew.
s0.IO.model.distModel(:)=3;

% Specify that the principal points in image-variant, i.e. each pp
% is its own block.
s0.IO.struct.block(2:3,:)=repmat(1:size(s0.IO.struct.block,2),2,1);

% Noise sigma [m].
noiseLevel=0.1;

% Reset random number generator.
rng('default');

% Perturb supplied EO data and use as initial values.
s0.EO.val=s0.EO.prior.val;
s0.EO.val(1:3,:)=s0.EO.val(1:3,:)+randn(3,size(s0.EO.val,2))*noiseLevel;

% Compute initial OP values by forward intersection.
s1=forwintersect(s0,'all',true);

% Warn for non-uniform mark std.
uniqueSigmas=unique(s1.IP.std(:));

if length(uniqueSigmas)~=1
    uniqueSigmas
    error('Multiple mark point sigmas')
end

if all(uniqueSigmas==0)
    warning('All mark point sigmas==0. Using sigma==1 instead.');
    s1.IP.sigmas=1;
    s1.IP.std(:)=1;
end

% Fix the datum by fixing camera 1...
s1.bundle.est.EO(:,1)=false;
% ...and the largest other absolute camera coordinate.
camDiff=abs(s1.EO.val(1:3,:)-repmat(s1.EO.val(1:3,1),1,size(s1.EO.val,2)));
[i,j]=find(camDiff==max(camDiff(:)));
s1.bundle.est.EO(i,j)=false;

fprintf('Running the bundle with damping %s...\n',damping);

% Run the bundle.
[result,ok,iters,sigma0,E]=bundle(s1,damping,'trace');
    
if ok
    fprintf('Bundle ok after %d iterations with sigma0=%.2f (%.2f pixels)\n',...
            iters,sigma0,sigma0*s1.IP.sigmas(1));
else
    fprintf(['Bundle failed after %d iterations. Last sigma0 estimate=%.2f ' ...
             '(%.2f pixels)\n'],iters,sigma0,sigma0*s1.IP.sigmas(1));
end

% Pre-factorize posterior covariance matrix for speed.
E=bundle_cov(result,E,'prepare');

[COP,result]=bundle_result_file(result,E,reportFile);

fprintf('\nBundle result file %s generated.\n',reportFile);

% Don't plot iteration history for the 26000+ object points.
h=plotparams(result,E,'noop');

h=plotcoverage(result,true);

h=plotimagestats(result,E);

h=plotopstats(result,E,COP);

fig=tagfigure(sprintf('damping=%s',damping));
fprintf('Displaying bundle iteration playback for method %s in figure %d.\n',...
        E.damping.name,double(fig));
plotnetwork(result,E,'trans','up','align',1,'title',...
            ['Damping: ',damping,'. Iteration %d of %d'], ...
            'axes',fig,'pause',doPause);

if nargout>0
    rr=result;
end

imName='';
imNo=1;
% Check if image files exist.
isAbsPath=~isempty(s1.proj.imDir) && ismember(s1.proj.imDir(1),'\\/') || ...
          length(s1.proj.imDir)>1 && s1.proj.imDir(2)==':';
if ~isAbsPath && exist(fullfile(curDir,s1.proj.imDir),'dir')
    % Expand path relative to current dir for this file.
    s1.proj.imDir=fullfile(curDir,s1.proj.imDir);
end
if exist(s1.proj.imDir,'dir')
    % Handle both original-case and lower-case file names.
    imNames={s1.EO.name{imNo},lower(s1.EO.name{imNo}),upper(s1.EO.name{imNo})};    
    imNames=fullfile(s1.proj.imDir,imNames);
    imExist=cellfun(@(x)exist(x,'file')==2,imNames);
    if any(imExist)
        imName=imNames{find(imExist,1,'first')};
    end
else
    warning('Image directory %s does not exist.',s1.proj.imDir);
end

if exist(imName,'file')
    fprintf('Plotting measurements on image %d.\n',imNo);
    imFig=tagfigure('image');
    h=[h;imshow(imName,'parent',gca(imFig))];
    pts=s1.IP.val(:,s1.IP.ix(s1.IP.vis(:,imNo),imNo));
    ptsId=s1.OP.id(s1.IP.vis(:,imNo));
    isCtrl=s1.OP.prior.isCtrl(s1.IP.vis(:,imNo));
    % Plot non-control points as red crosses.
    if any(~isCtrl)
        line(pts(1,~isCtrl),pts(2,~isCtrl),'marker','x','color','r',...
             'linestyle','none','parent',gca(imFig));
    end
    % Plot control points as black-yellow triangles.
    if any(isCtrl)
        line(pts(1,isCtrl),pts(2,isCtrl),'marker','^','color','k',...
             'markersize',2,'linestyle','none','parent',gca(imFig));
        line(pts(1,isCtrl),pts(2,isCtrl),'marker','^','color','y',...
             'markersize',6,'linestyle','none','parent',gca(imFig));
    end
    for i=1:length(ptsId)
        text(pts(1,i),pts(2,i),int2str(ptsId(i)),'horizontal','center',...
             'vertical','bottom','color','b','parent',gca(imFig));
    end
end
