function dva = pix2dva(pixels, eyeScreenDistance, windowRect, screenHeight)
% PIX2DVA Convert pixels to degrees of visual angle
%   dva = pix2dva(pixels, eyeScreenDistance, windowRect, screenHeight)
%
%   Inputs:
%       pixels           - Number of pixels
%       eyeScreenDistance - Distance from eye to screen in cm
%       windowRect       - PTB window rect [0 0 width height]
%       screenHeight     - Physical screen height in cm
%
%   Output:
%       dva - Degrees of visual angle corresponding to the pixels

dva = atand(pixels * screenHeight / (eyeScreenDistance * windowRect(4)));
