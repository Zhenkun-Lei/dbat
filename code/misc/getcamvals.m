function v=getcamvals(s,cams,varargin)
%GETCAMVALS Get camera parameters by name from DBAT struct.
%
%   V=GETCAMVALS(S,CAMS,PARAM) returns the M-by-N array V with the
%   camera parameters specified by the string PARAM for the camera
%   with indices in the N-vector CAMS. Use CAMS='all' to get the
%   values for all cameras. The number of rows M are different with
%   different PARAM values. Individual elements (M=1) correspond to the
%   following values PARAM strings:
%   - 'cc' - camera constant.
%   - 'px' - principal point x coordinate. 
%   - 'py' - principal point y coordinate. 
%   - 'as' - aspect parameter.
%   - 'sk' - skew parameter.
%   - 'Ki' - radial lens distortion coefficient number i.
%   - 'Pi' - tangential lens distortion coefficient number i.
%   - 'iw' - image width (pixels).
%   - 'ih' - image height (pixels).
%   - 'sw' - sensor width (mm).
%   - 'sh' - sensor height (mm).
%
%   For groups of values, the following PARAM strings may be used:
%   - 'pp' - principal point [px;py], M=2.
%   - 'af' - affine; [cc;px;py;as;sk], M=5.
%   - 'K'  - all radial coefficients, M=s.IO.model.nK.
%   - 'P'  - all tangential coefficients, M=s.IO.model.nP.
%   - 'cam' - all camera parameters, 'cc' to 'Pi'.
%   - 'isz' - image size [iw;ih].
%   - 'ssz' - sensor size [sw;sh].
%
%   V=GETCAMVALS(S,CAMS,PARAM1,PARAM2,...) can be used to return
%   arbitrary combination of values. Successive PARAM values will
%   be appended to the bottom of V.
%
%   V=GETCAMVALS(S,CAMS,'std',PARAM1,PARAM2,...) will instead return
%   the posterior standard deviation(s) of PARAM1, PARAM2, etc.
%
%   The special PARAM string 'KCAM' may be used to return a
%   3-by-3-by-N array with the affine camera calibration matrices for
%   each camera. 'KCAM' cannot be combined with any other PARAM
%   string nor with 'std'.
%
%See also: BUILDPARAMTYPES, SETCAMVALS, SETCAMEST.

if ischar(cams)
    if strcmp(cams,'all')
        cams=1:size(s.IO.val,2);
    else
        error('Bad CAMS string.');
    end
end

% Check for 'KCAM'
if any(strcmp('KCAM',varargin))
    % 'KCAM' must be by itself.
    if length(varargin)>1
        error('''KCAM'' must appear as solitary PARAM string');
    end
    v=nan(3,3,length(cams));
    for i=1:length(cams)
        cc=s.IO.val(1,cams(i));
        pp=s.IO.val(2:3,cams(i));
        v(:,:,i)=[-cc*eye(2),pp;0,0,1];
    end
else
    ix=zeros(0,1);
    if ~isempty(varargin) && strcmp(varargin{1},'std')
        % Read posterior standard deviations.
        varargin(1)=[];
        val=[s.post.std.IO;
             zeros(4,size(s.post.std.IO,2))];
    else
        % Read values.
        val=[s.IO.val;
             s.IO.sensor.imSize;
             s.IO.sensor.ssSize];
    end

    for i=1:length(varargin)
        j=[];
        switch varargin{i}
          case 'cc'
            j=1;
          case 'px'
            j=2;
          case 'py'
            j=3;
          case 'as'
            j=4;
          case 'sk'
            j=5;
          case 'pp'
            j=(2:3)';
          case 'af'
            j=(1:5)';
          case 'K'
            j=5+(1:s.IO.model.nK)';
          case 'P'
            j=5+s.IO.model.nK+(1:s.IO.model.nP)';
          case 'cam'
            j=(1:5+s.IO.model.nK+s.IO.model.nP)';
          case 'iw'
            j=5+s.IO.model.nK+s.IO.model.nP+1;
          case 'ih'
            j=5+s.IO.model.nK+s.IO.model.nP+2;
          case 'isz'
            j=5+s.IO.model.nK+s.IO.model.nP+(1:2)';
          case 'sw'
            j=5+s.IO.model.nK+s.IO.model.nP+3;
          case 'sh'
            j=5+s.IO.model.nK+s.IO.model.nP+4;
          case 'ssz'
            j=5+s.IO.model.nK+s.IO.model.nP+(3:4)';
          otherwise
            ss=[varargin{i},' '];
            switch ss(1)
              case 'K'
                k=str2double(ss(2:end));
                if k<1 || k>s.IO.model.nK
                    error('Bad K parameter');
                end
                j=5+k;
              case 'P'
                k=str2double(ss(2:end));
                if k<1 || k>s.IO.model.nP
                    error('Bad P parameter');
                end
                j=5+s.IO.model.nK+k;
            end
        end
        if isempty(j)
            error('Bad PARAM ''%s''',varargin{i});
        end
        ix=[ix;j];
    end
    
    v=val(ix,cams);
end
