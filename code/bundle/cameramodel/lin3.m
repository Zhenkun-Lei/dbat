function [Q,dQ,dQn]=lin3(M,P,varargin)
%LIN3 3D linear transform for the DBAT projection model
%
%   Q=LIN3(M,P) applies the linear transform M to the 3D points in the
%   3-by-N array P, i.e. computes M*P.
%
%   [Q,dQ]=... also returns a struct dQ with the analytical Jacobians
%   with respect to M and P in the fields dM and dP. For more details,
%   see DBAT_BUNDLE_FUNCTIONS.
%
%SEE ALSO: DBAT_BUNDLE_FUNCTIONS

% Treat selftest call separately.
if nargin>=1 && ischar(M), Q=selftest(nargin>1 && P); return; end

% Otherwise, verify number of parameters.
narginchk(2,4);

Q=[];
dQ=[];
dQn=[];

if nargout>1
    % Construct empty Jacobian struct.
    dQ=struct('dP',[],...
              'dM',[]);
    dQn=dQ;
end

% What Jacobians to compute?
cM=nargout>1 && (length(varargin)<1 || varargin{1});
cP=nargout>1 && (length(varargin)<2 || varargin{2});

%% Test parameters
[m,n]=size(P);
if m~=3 || any(size(M)~=m)
    error([mfilename,': bad size']);
end

%% Actual function code
Q=M*P;

if nargout>2
    %% Numerical Jacobian

    % FMT is function handle to repackage vector argument to what
    % the function expects.
    if cP
        fmt=@(P)reshape(P,3,[]);
        fun=@(P)feval(mfilename,M,fmt(P));
        dQn.dP=jacapprox(fun,P);
    end
    if cM
        fmt=@(M)reshape(M,3,[]);
        fun=@(M)feval(mfilename,fmt(M),P);
        dQn.dM=jacapprox(fun,M);
    end
end

if nargout>1
    %% Analytical Jacobian
    if cP
        dQ.dP=kron(speye(n),M);
    end
    if cM
        dQ.dM=kron(P',speye(m));
    end    
end


function fail=selftest(verbose)

% Set up test data.
m=3;
n=5;
M=rand(m);
P=rand(m,n);

fail=full_self_test(mfilename,{M,P},1e-8,1e-8,verbose);
