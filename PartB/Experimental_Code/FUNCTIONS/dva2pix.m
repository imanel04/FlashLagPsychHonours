function pixel = dva2pix(dva,eyeScreenDistance,windowRect,screenHeight)
% DVA2PIX Convert degrees of visual angle to pixels
%   pixel = dva2pix(dva, eyeScreenDistance, windowRect, screenHeight)
%
%   Inputs:
%       dva              - Degrees of visual angle
%       eyeScreenDistance - Distance from eye to screen in cm
%       windowRect       - PTB window rect [0 0 width height]
%       screenHeight     - Physical screen height in cm
%
%   Output:
%       pixel - Number of pixels corresponding to the DVA

pixel = round(tand(dva) * eyeScreenDistance * windowRect(4) / screenHeight);
