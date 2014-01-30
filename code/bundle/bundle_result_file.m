function bundle_result_file(s,e,f)
%BUNDLE_RESULT_FILE Generate result file of bundle run.
%
%   BUNDLE_RESULT_FILE(S,E,F), where S and E are BUNDLE return files and
%   F is a string, writes a text result file to the file F. The text
%   result file contain information about the project, the status of the
%   estimation process, and the quality of the result.
%
%See also: BUNDLE, BUNDLE_COV. 

% $Id$

fid=fopen(f,'wt');
if fid<0
    error('DBAT:bundle_result_file:fileError',...
          ['Failed to open file ''',f,''' for writing.']);
end

corrThreshold=0.95;

% Header info
fprintf(fid,'Damped Bundle Adjustment Toolbox result file\n');
p=repmat(' ',1,3);
fprintf(fid,[p,'Project Name: %s\n'],s.title);

fprintf(fid,[p,'Problems and suggestions:\n']);
fprintf(fid,[p,p,'Project Problems: Not evaluated\n']);

% Check if we have any large correlations.
[iio,jio,kio,vio,CIO]=high_io_correlations(s,e,corrThreshold);
[ieo,jeo,keo,veo,CEO]=high_eo_correlations(s,e,corrThreshold);
[iop,jop,kop,vop,COP]=high_op_correlations(s,e,corrThreshold);

n=any(iio)+any(ieo)+any(iop);

fprintf(fid,[p,p,'Problems related to the processing: (%d)\n'],n);

if any(iio)
    fprintf(fid,[p,p,p,'One or more of the camera parameter deviations ' ...
                 'has a high correlation (see below).\n']);
end
if any(ieo)
    fprintf(fid,[p,p,p,'One or more of the camera station parameter ' ...
                 'deviations has a high correlation (see below).\n']);
end
if any(iop)
    fprintf(fid,[p,p,p,'One or more of the object point coordinate ' ...
                 'deviations has a high correlation.\n']);
end

% Info about last bundle.
fprintf(fid,[p,'Information from last bundle\n']);
fprintf(fid,[p,p,'Last Bundle Run: %s\n'],e.dateStamp);
fprintf(fid,[p,p,'DBAT version: %s\n'],e.version);
if e.code==0
    status='OK';
else
    status='fail';
end
fprintf(fid,[p,p,'Status: %s (%d)\n'],status,e.code);
fprintf(fid,[p,p,'Sigma0 (pixels): %g\n'],e.s0px);
fprintf(fid,[p,p,'Sigma0 (mm): %g\n'],e.s0mm);
fprintf(fid,[p,p,'Processing options:\n']);
fprintf(fid,[p,p,p,'Orientation: on\n']);
fprintf(fid,[p,p,p,'Global optimization: on\n']);
offon={'off','on'};
fprintf(fid,[p,p,p,'Calibration: %s\n'],offon{double(any(s.cIO(:)))+1});
fprintf(fid,[p,p,p,'Constraints: off\n']);
fprintf(fid,[p,p,p,'Maximum # of iterations: %d\n'],e.maxIter);
fprintf(fid,[p,p,p,'Convergence tolerance: %g\n'],e.convTol);
fprintf(fid,[p,p,p,'Singular test: %s\n'],offon{double(e.singularTest)+1});
fprintf(fid,[p,p,p,'Chirality veto: %s\n'],offon{double(e.chirality)+1});
fprintf(fid,[p,p,p,'Damping: %s\n'],e.damping.name);

fprintf(fid,[p,p,'Total error:\n']);
fprintf(fid,[p,p,p,'Initial value comment: %s\n'],s.x0desc);
fprintf(fid,[p,p,p,'Number of stages: %d\n'],1);
fprintf(fid,[p,p,p,'Number of iterations: %d\n'],e.usedIters);
fprintf(fid,[p,p,p,'First error: %g\n'],e.res(1));
fprintf(fid,[p,p,p,'Last error: %g\n'],e.res(end));

fprintf(fid,[p,p,'Precisions / Standard Deviations:\n']);

if any(s.cIO(:))
    % Camera calibration results.
    fprintf(fid,[p,p,p,'Camera Calibration Standard Deviations:\n']);
    
    % IO standard devation. Correlations were computed far above.
    ioSigma=reshape(sqrt(diag(CIO)),size(s.IO,1),[]);

    % Headers and values to print.
    head={'Focal Length','Xp - principal point x','Yp - principal point y',...
          'Fw - format width','Fh - format height',...
          'K1 - radial distortion 1','K2 - radial distortion 2',...
          'K3 - radial distortion 3',...
          'P1 - decentering distortion 1','P2 - decentering distortion 2'};
    names={'Focal','Xp','Yp','Fw','Fh','K1','K2','K3','P1','P2'};
    unit={'mm','mm','mm','mm','mm','mm^(-2)','mm^(-4)','mm^(-6)',...
           'mm^(-2)','mm^(-2)'};
    % Original-to-presentation order mapping and inverse.
    rows=[3,1:2,11:12,4:6,7:8];
    irows=sparse(rows,1,1:length(rows));

    S=diag([1,1,-1,1,1,-1,-1,-1,-1,-1]);

    % Add symmetric correlations.
    iio0=iio;
    iio=[iio;jio];
    jio=[jio;iio0];
    kio=repmat(kio,2,1);
    vio=repmat(vio,2,1);
    
    for i=1:size(s.cIO,2)
        vals=S*full(s.IO(rows,i));
        sigma=full(ioSigma(rows,i));
        fprintf(fid,[p,p,p,p,'Camera%d: Unknown\n'],i);
        for j=1:length(head)
            fprintf(fid,[p,p,p,p,p,'%s:\n'],head{j});
            fprintf(fid,[p,p,p,p,p,p,' Value: %g %s\n'],vals(j),unit{j});
            if sigma(j)~=0
                fprintf(fid,[p,p,p,p,p,p,' Deviation: %.1g %s\n'],...
                        sigma(j),unit{j});
            end
            highCorr=find(kio==i & iio==rows(j));
            if any(highCorr)
                otherParam=irows(jio(highCorr));
                ss='';
                for kk=1:length(otherParam)
                    ss=[ss,sprintf(' %s:%.1f%%,',names{otherParam(kk)},...
                                   vio(highCorr(kk))*100)];
                end
                ss(end)='.';
                fprintf(fid,[p,p,p,p,p,p,' Correlations over %.1f%%:%s\n'],...
                        corrThreshold*100,ss);
            end
        end    
    end
end

fprintf(fid,[p,p,p,'Photograph Standard Deviations:\n']);

% Get camera station covariances.
CEO=bundle_cov(s,e,'CEOF');
% Compute corresponding correlations and standard deviations.
[CEOC,eoSigma]=corrmat(CEO,true);
eoSigma=reshape(eoSigma,6,[]);

% Headers and values to print.
head={'Omega','Phi','Kappa','Xc','Yc','Zc'};
unit={'deg','deg','deg','','',''};
names=head;

% Original-to-presentation order mapping and inverse.
rows=[4:6,1:3];
irows=sparse(rows,1,1:length(rows));

% Scaling matrix to degrees.
S=diag([180/pi*ones(1,3),ones(1,3)]);

% Add symmetric correlations.
ieo0=ieo;
ieo=[ieo;jeo];
jeo=[jeo;ieo0];
keo=repmat(keo,2,1);
veo=repmat(veo,2,1);

for i=1:size(s.EO,2)
    fprintf(fid,[p,p,p,p,'Photo %d: %s\n'],i,s.imNames{i});
    vals=S*s.EO(rows,i);
    sigma=S*eoSigma(rows,i);
    for j=1:6
        fprintf(fid,[p,p,p,p,p,'%s:\n'],head{j});
        fprintf(fid,[p,p,p,p,p,p,'Value: %.6f %s\n'],vals(j),unit{j});
        if sigma(j)~=0
            fprintf(fid,[p,p,p,p,p,p,'Deviation: %.1g %s\n'],sigma(j),unit{j});
        end
        highCorr=find(keo==i & ieo==rows(j));
        if any(highCorr)
            otherParam=irows(jeo(highCorr));
            ss='';
            for kk=1:length(otherParam)
                ss=[ss,sprintf(' %s:%.1f%%,',names{otherParam(kk)},...
                               veo(highCorr(kk))*100)];
            end
            ss(end)='.';
            fprintf(fid,[p,p,p,p,p,p,'Correlations over %.1f%%:%s\n'],...
                    corrThreshold*100,ss);
        end
    end
end

fprintf(fid,[p,'Quality\n']);

fprintf(fid,[p,p,'Photographs\n']);
fprintf(fid,[p,p,p,'Total number: %d\n'],length(s.imNames));
fprintf(fid,[p,p,p,'Numbers used: %d\n'],size(s.EO,2));

fprintf(fid,[p,p,'Cameras\n']);
fprintf(fid,[p,p,p,'Total number: %d\n'],size(s.IO,2));
for i=1:size(s.IO,2)
    fprintf(fid,[p,p,p,'Camera%d:\n'],i);

    if any(s.cIO(:,i))
        fprintf(fid,[p,p,p,p,'Calibration: yes\n']);
    else
        fprintf(fid,[p,p,p,p,'Calibration: <not available>\n']);
    end

    fprintf(fid,[p,p,p,p,'Number of photos using camera: %d\n'],nnz(s.cams==i));

    % Compute individual and union coverage.
    [c,cr]=coverage(s,find(s.cams==i));
    [uc,ucr]=coverage(s,find(s.cams==i),true);
    fprintf(fid,[p,p,p,p,'Photo point coverage:\n']);
    fprintf(fid,[p,p,p,p,p,'Rectangular: %d%%-%d%% ',...
                 '(%d%% average, %d%% median, %d%% union)\n'],...
            round(min(cr*100)),round(max(cr*100)),round(mean(cr*100)),...
            round(median(cr*100)),round(ucr*100));
    fprintf(fid,[p,p,p,p,p,'Convex hull: %d%%-%d%% ',...
                 '(%d%% average, %d%% median, %d%% union)\n'],...
            round(min(c*100)),round(max(c*100)),round(mean(c*100)),...
            round(median(c*100)),round(uc*100));
end

fprintf(fid,[p,p,'Photo Coverage\n']);
fprintf(fid,[p,p,p,'References points outside calibrated region:\n']);
if any(s.cIO(:))
    % Print nothing.
else
    fprintf(fid,[p,p,p,p,'<not available>\n']);
end

fprintf(fid,[p,p,'Point Marking Residuals\n']);

% stuff

fprintf(fid,[p,p,'Point Precision\n']);

% stuff

% total variance

fprintf(fid,[p,p,'Point Angles\n']);

fclose(fid);