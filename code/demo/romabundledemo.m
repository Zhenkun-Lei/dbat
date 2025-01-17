function [rr,s0,prob]=romabundledemo(damping,doPause)
%ROMABUNDLEDEMO Bundle demo for DBAT.
%
%   ROMABUNDLEDEMO runs the bundle on the PhotoModeler export file
%   of the ROMA data set. The PhotoModeler EO values are used as
%   initial values, except that the EO position are disturbed by
%   random noise with sigma=0.1 m. The OP initial values are
%   computed by forward intersection. The datum is defined by
%   fixing the EO parameters of the first camera and the X
%   coordinate of another camera. The other camera is chosen to
%   maximize the baseline.
%
%   ROMABUNDLEDEMO uses the Gauss-Newton-Armijo damping scheme of [1]
%   by default. Use CAMCALDEMO(DAMPING), where DAMPING is one of
%   - 'none' or 'gm' for classical Gauss-Markov iterations,
%   - 'gna'          Gauss-Newton with Armijo linesearch,
%   - 'lm'           Levenberg-Marquardt, or
%   - 'lmp'          Levenberg-Marquardt with Powell dogleg.
%
%   Use ROMABUNDLEDEMO(DAMPING,'off') to visualize the iteration
%   sequence without waiting for a keypress.
%
%   References:
%       [1] Börlin and Grussenmeyer (2013). "Bundle adjustment with
%       and without damping", Photogrammetric Record,
%       vol. 28(144):396-415.

if nargin<1, damping='gna'; end

if nargin<2, doPause='on'; end

switch damping
  case {'none','gm','gna','lm','lmp'}
    % Do nothing.
  otherwise
    error('Bad damping');
end

% Base dir with input files.
inputDir=fullfile(fileparts(dbatroot),'data','dbat');

% PhotoModeler text export file and report file.
inputFile=fullfile(inputDir,'pmexports','roma-pmexport.txt');
% Report file name.
reportFile=fullfile(inputDir,'dbatexports','roma-dbatreport.txt');;

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

% Default distortion model is now 3: With aspect/skew.
s0.IO.model.distModel(:)=3;

% Fixed camera parameters.
s0=setcamvals(s0,'loaded');
s0=setcamest(s0,'not','all');

% Reset random number generator.
rng('default');

% Noise sigma [m] for EO positions.
noiseLevel=0.1;

% Perturb supplied EO data and use as initial values.
s0.EO.val=s0.prior.EO.val;
s0.EO.val(1:3,:)=s0.EO.val(1:3,:)+randn(3,size(s0.EO.val,2))*noiseLevel;

% Clear all non-control OP.
s0=clearop(s0);

% Compute initial OP values by forward intersection.
s1=forwintersect(s0,'all',true);

% Set up for dependent relative orientation with base camera 1.
s1=seteoest(s1,'depend',1);

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

result=bundle_result_file(result,E,reportFile);

fprintf('\nBundle result file %s generated.\n',reportFile);

% Don't plot iteration history for the 26000+ object points.
h=plotparams(result,E,'noop');

h=plotcoverage(result,true);

h=plotimagestats(result,E);

h=plotopstats(result,E);

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
if ~isAbsPath && exist(fullfile(fileparts(dbatroot),s1.proj.imDir),'dir')
    % Expand path relative to current dir for this file.
    s1.proj.imDir=fullfile(fileparts(dbatroot),s1.proj.imDir);
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
    isCtrl=s1.prior.OP.isCtrl(s1.IP.vis(:,imNo));
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
