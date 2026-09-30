function se = ste(x)
% STE Calculate standard error of the mean
%   se = ste(x)
%
%   Input:
%       x - Vector of values
%
%   Output:
%       se - Standard error of the mean

se = std(x) / sqrt(length(x));
