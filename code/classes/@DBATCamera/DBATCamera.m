classdef DBATCamera
    properties (Access = public)
        Id {mustBeNumericScalar} = nan
        Name {mustBeSingleString} = ''
        Unit {mustBeSingleString} = ''
        SensorSize {mustBe2Vector} = nan(1,2)
        ImageSize {mustBe2Vector} = nan(1,2)
        FocalLength {mustBeNumericScalar} = nan
        AspectRatio {mustBeNumericScalar} = nan
        Skew {mustBeNumericScalar} = nan
        CameraConstant {mustBeNumericScalar} = nan
        PrincipalPoint {mustBe2Vector} = nan(1,2)
        K {mustBeNumericVector} = nan(1,0)
        P {mustBeNumericVector} = nan(1,0)
        Model {mustBeNumericScalar} = nan
        Calibrated {mustBeLogicalScalar}  = false
        CalibrationInfo {mustBeStruct} = struct
    end
    
    methods
        function display(obj)
            fprintf('%20s: %d\n','Id',obj.Id);
            fprintf('%20s: ''%s''\n','Name',obj.Name);
            fprintf('%20s: ''%s''\n','Unit',obj.Unit);
            fprintf('%20s: [%g %g] %s\n','Sensor size',obj.SensorSize,obj.Unit);
            fprintf('%20s: [%g %g] px\n','Image size',obj.ImageSize);
            fprintf('%20s: %g %s\n','Focal length',obj.FocalLength,obj.Unit);
            fprintf('%20s: %g (diff=%g)\n','Aspect ratio',obj.AspectRatio,...
                    AspectDiff(obj));
            fprintf('%20s: %g\n','Skew',obj.Skew);
            fprintf('%20s: %g %s\n','Camera constant', ...
                    obj.CameraConstant,obj.Unit);
            fprintf('%20s: [%g %g] %s\n','Principal point', ...
                    obj.PrincipalPoint,obj.Unit);
            if isempty(obj.K)
                fprintf('%20s: []\n','K');
            else
                s=join(repmat({'%g'},1,length(obj.K)),' ');
                Kfmt=['%20s: [',s{1},']\n'];
                fprintf(Kfmt,'K',obj.K);
            end
            if isempty(obj.P)
                fprintf('%20s: []\n','P');
            else
                s=join(repmat({'%g'},1,length(obj.P)),' ');
                Pfmt=['%20s: [',s{1},']\n'];
                fprintf(Pfmt,'P',obj.P);
            end
            fprintf('%20s: %d\n','Model',obj.Model);
            noYes={'No','Yes'};
            fprintf('%20s: %s\n','Calibrated',noYes{double(obj.Calibrated)+1});
        end
        
        % Return the aspect difference, i.e., one minus the aspect.
        function v=AspectDiff(obj)
            v=1-obj.AspectRatio;
        end
        
        function value=asVector(obj)
            value=[obj.CameraConstant,obj.PrincipalPoint, ...
                   AspectDiff(obj),obj.Skew,obj.K,obj.P]';
        end

        % Compute the pixel size in camera units per pixel.
        function value=PixelSize(obj)
            value=obj.SensorSize./obj.ImageSize;
        end
        
        % Compute the image resolution in pixels per camera unit.
        function value=ImageResolution(obj)
            value=obj.ImageSize./obj.SensorSize;
        end
        
        % Return the length of K
        function value=nK(obj)
            value=length(obj.K);
        end
        
        % Return the length of P
        function value=nP(obj)
            value=length(obj.P);
        end
        
    end
end

function mustBeSingleString(s)
    if ~ischar(s) || ~(isempty(s) || size(s,1)==1)
        error('Value must be a string');
    end
end

function mustBe2Vector(s)
    if ~isnumeric(s) || any(size(s)~=[1,2])
        error('Value must be a numeric 2-vector');
    end
end

function mustBeNumericVector(s)
    if ~isnumeric(s) || size(s,1)~=1
        error('Value must be a numeric row vector');
    end
end

function mustBeNumericScalar(s)
    if ~isnumeric(s) || ~isscalar(s)
        error('Value must be a numeric scalar');
    end
end

function mustBeLogicalScalar(s)
    if ~islogical(s) || ~isscalar(s)
        error('Value must be a logical scalar');
    end
end

function mustBeStruct(s)
    if ~isstruct(s)
        error('Value must be a struct');
    end
end

