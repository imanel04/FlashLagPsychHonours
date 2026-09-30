%========================================================================================
%%               FLASH-LAG EFFECT CENTRAL-CUE & BASELINE EXPERIMENT
%                           Experiment 3 (E3)
%                      Last modified: Jul 23, 2026
% =========================================================================================
%
%%  DESCRIPTION
%      Psychophysical experiment measuring the two components of the Flash-Lag
%      Effect in isolation:
%        - the motion (moving-stimulus) position bias, cued by a central cue
%        - the static flash position bias
%
%%  CONDITIONS
%      1. centralcue    - moving stimulus + central cue (no flash) -> motion bias
%      2. flashbaseline - flash alone, no motion            -> flash bias
%
%%  FACTORIAL DESIGN (INTERLEAVED)
%      Eccentricities : 8, 10, 12, 14 DVA          (no jitter)
%      Speeds         : 10, 15, 20 DVA/s           (motion only)
%      Directions     : petal (inward), fugal (outward)   (motion only)
%
%      MOTION (centralcue)    : 2 dir x 4 ecc x 3 speed = 24 unique cells
%      STATIC (flashbaseline) : 2 x 4 ecc            =  8 unique cells
%
%      One design-cycle = all 24 motion + 8 static cells = 32 trials. Blocks are
%      built from whole design-cycles, then shuffled, so motion and static are
%      randomly interleaved in a fixed 3:1 ratio and every block is internally
%      balanced over all cells. Set BOTH design.numBlocks and
%      design.trialsPerBlock; trialsPerBlock must be a whole multiple of 32.
%
%      Quadrant (45/135/225/315) and probe-start position are balanced within
%      each block but are NOT experimental factors.
%
%      MOTION SWEEP GEOMETRY: the stimulus reaches the flash point (= ecc) at
%      the midpoint of a fixed 500 ms sweep; travel is symmetric about it:
%        half_travel = speed * 0.25 s ; inner = ecc - half_travel ; outer = ecc + half_travel
%
%%  RESPONSE
%      Method of adjustment - mouse moves a grey probe locked to the trajectory.
%
%%  MONITOR
%      Set the display to its NATIVE resolution at 120 Hz yourself before
%      running (the script does not change resolution). Screen height must be correct
%      (= screenHeight below; verify with a ruler on
%      the monitor), or every DVA computation is wrong.
%==========================================================================================

clear; close all;

%% EXPERIMENT SETUP

expInfo.version = 'E3_v23072026';
% sbjname is TYPED ON-SCREEN at startup (SUBJECT ID ENTRY, after the window
% opens)

% Randomise and RECORD the RNG seed so any session's trial order is
% reproducible (logged to console, every CSV row, and the timing PDF).
rng('shuffle');
rngState = rng;   % query AFTER shuffling: rng('shuffle') returns the PREVIOUS state
fprintf('RNG seed for this session: %u\n', rngState.Seed);
expInfo.rngSeed = rngState.Seed;

% Design parameters
design.eccDva       = [8, 10, 12, 14];   % eccentricities (DVA), no jitter
design.speedsDva    = [10, 15, 20];      % stimulus speeds (DVA/s), motion only
design.sweepDur     = 0.5;               % motion sweep duration (s); ALSO the
                                         % flash-baseline trial duration (matched)

% Block configuration: 
design.trialsPerBlock = 32;              % <-- whole multiple of 32
design.numBlocks      = 12;               % <-- number of blocks

% PRACTICE BLOCK: a short unlogged warm-up run before block 1. Trials are
% drawn from the same design cells as the real blocks (same 3:1 motion:static
% ratio), but NOTHING is written to the CSV and no timing data is collected.
% The participant can end it early at any point with the SPACE bar. Set to 0
% to disable the practice block entirely.
design.practiceTrials = 12;               % <-- practice trial count

isEyelink = 1;                           % Set 1 for eyetracker ON 

%----------------------------------------------------------------------
%%                     PSYCHTOOLBOX INITIALIZATION
%----------------------------------------------------------------------

Screen('Preference', 'SkipSyncTests', 0);
Screen('Preference', 'VBLTimestampingMode', 1);
Screen('Preference', 'ConserveVRAM', 0);
KbName('UnifyKeyNames'); 
screens = Screen('Screens');
screenNumber = max(screens); % Set this to the appropriate screen for display.

% Add function path
addpath(fullfile(fileparts(mfilename('fullpath')), 'FUNCTIONS'));

%----------------------------------------------------------------------
%%                         DISPLAY PARAMETERS
%----------------------------------------------------------------------
black = BlackIndex(screenNumber);
white = WhiteIndex(screenNumber);
grey = white / 2;
red = [220 100 100];  

% Expected refresh rate
refreshRate = 120;

% MUTE macOS ALERT SOUNDS during experiment
% Save current alert volume and set to 0
try
    [~, alertVolumeStr] = system('osascript -e "get alert volume of (get volume settings)"');
    originalAlertVolume = str2double(strtrim(alertVolumeStr));
    if isnan(originalAlertVolume)
        originalAlertVolume = 100;  % Default if parsing fails
    end
    system('osascript -e "set volume alert volume 0"');
catch
    originalAlertVolume = 100;  % Default if command fails
end

% NOTE: this script does NOT change the display resolution. Configure the
% monitor to its native resolution at 120 Hz yourself before running. The
% refresh assert below still stops the session if the rate is wrong.
%
% commandwindow BEFORE opening the window, never after: called after, it
% hands focus to MATLAB and macOS then ignores HideCursor until the first
% click inside the fullscreen window (= visible arrow through trial 1).
commandwindow;
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);

% Suppress keyboard input to MATLAB command window
ListenChar(-1);

% CURSOR: detached from the mouse for the whole session (macOS-only
% SetMouse(...,1) freezes the visible cursor; physical movement no longer
% moves it) and parked in the BOTTOM-RIGHT CORNER. The arrow glyph extends
% down-right from its hotspot, so with the hotspot on the corner pixel the
% glyph is clipped off-screen - at most one static pixel can ever show, even
% while macOS refuses to hide it (which it does until the first click).
% Mouse motion is read as raw deltas from GetMouse's valuators
% (valuators(1:2) = deltaX/deltaY since last query on macOS).
% Re-attached in every exit path; if MATLAB dies mid-session, recover with:
%   SetMouse(500, 500, 0, [], 0); ShowCursor;
cursorParkX = windowRect(3) - 1;
cursorParkY = windowRect(4) - 1;
[~, ~, ~, ~, testValuators] = GetMouse(window);
assert(IsOSX && numel(testValuators) >= 2, ...
    'Cursor handling needs macOS + a PTB with GetMouse valuator deltas (>= 3.0.14).');
SetMouse(cursorParkX, cursorParkY, screenNumber, [], 1);   % freeze + park
HideCursor(screenNumber);

% Query actual frame rate
ifi = Screen('GetFlipInterval', window); %Get the vertical refresh rate of the monitor
measuredRefreshRate = round(1/ifi);
assert(abs(measuredRefreshRate - refreshRate) <= 2, ...
    'Refresh rate mismatch: measured %d Hz, expected %d Hz', measuredRefreshRate, refreshRate);

% GPU optimizations
Priority(MaxPriority(window));  % Maximum CPU priority
% Alpha blending ON so the round (alpha-masked) disk textures composite as
% circles rather than their square bounding boxes.
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

eyeScreenDistance = 57;
screenHeight = 30.26;
xCenter = windowRect(3) / 2;
yCenter = windowRect(4) / 2;

% Quadrant angles
quadrants = [45 135 225 315];

% Pre-computed key codes (avoids per-frame KbName lookups on hot paths)
escapeKey = KbName('ESCAPE');
rKey      = KbName('r');
spaceKey  = KbName('space');   % ends the practice block early

%----------------------------------------------------------------------
%%                   SUBJECT ID ENTRY (first screen)
%----------------------------------------------------------------------
% Typed directly on the experiment display with a blinking cursor. Letters,
% digits and hyphen are accepted; backspace deletes; Enter (non-empty)
% confirms; ESC aborts the session cleanly. The screen is redrawn and
% flipped every iteration to keep the flip cadence alive (same Apple
% Silicon stutter rationale as the instruction screen).
returnKey    = KbName('Return');
backspaceKey = KbName('DELETE');   % macOS "delete" key = backspace
sbjname = '';
Screen('TextFont', window, 'Futura');
Screen('TextSize', window, 50);
KbReleaseWait();
enteringID = true;
while enteringID
    % Blinking cursor: visible during the first half of every second
    if mod(GetSecs(), 1) < 0.5
        idCursor = '|';
    else
        idCursor = ' ';
    end
    Screen('FillRect', window, black);
    DrawFormattedText(window, 'Enter subject ID', 'center', yCenter - 120, white);
    DrawFormattedText(window, [sbjname idCursor], 'center', 'center', grey);
    Screen('Flip', window);

    [keyIsDown, ~, keyCode] = KbCheck();
    if keyIsDown
        if any(keyCode(returnKey)) && ~isempty(sbjname)
            enteringID = false;
        elseif any(keyCode(backspaceKey))
            if ~isempty(sbjname)
                sbjname = sbjname(1:end-1);
            end
        elseif keyCode(escapeKey)
            % Abort: restore everything changed so far, then stop the script
            Priority(0);
            ListenChar(0);
            try SetMouse(cursorParkX, cursorParkY, screenNumber, [], 0); catch, end
            ShowCursor;
            sca;
            try
                system(sprintf('osascript -e "set volume alert volume %d"', originalAlertVolume));
            catch
            end
            fprintf('Session aborted at the subject ID screen.\n');
            return;
        else
            % Single-character keys only: 'a', '1!' etc. KbName strings for
            % non-character keys ('space', 'LeftShift', ...) are longer than
            % 2 chars and are ignored, as is any second held key.
            keyName = KbName(find(keyCode, 1));
            if ischar(keyName) && numel(keyName) <= 2 && numel(sbjname) < 20
                ch = keyName(1);
                if isstrprop(ch, 'alphanum') || ch == '-'
                    sbjname = [sbjname, ch];
                end
            end
        end
        KbReleaseWait();   % one character per physical keypress
    end
end
KbReleaseWait();
fprintf('Subject ID: %s\n', sbjname);

%% FIXATION CROSS
fixCrossDimDva = 0.5;
fixCrossDimPix = dva2pix(fixCrossDimDva, eyeScreenDistance, windowRect, screenHeight);
fixCoords = [-fixCrossDimPix fixCrossDimPix 0 0; 0 0 -fixCrossDimPix fixCrossDimPix];
fixLineWidth = 3;
fixDuration = 0.5;

%% DISK TEXTURE HELPER
% Builds an anti-aliased filled disk as an RGBA image (square canvas, alpha=0
% outside the circle). colorRGB is a 1x3 in [0..white]. diamPix is the disk
% diameter in pixels. Returns a HxWx4 uint8/double image suitable for MakeTexture.
makeDiskImage = @(diamPix, colorRGB) local_makeDisk(diamPix, colorRGB, white);

%% MOVING STIMULUS PARAMETERS (White disk, 1 DVA diameter) - central cue condition
stimulus.DiamDva = 1.0;
stimulus.DiamPix = dva2pix(stimulus.DiamDva, eyeScreenDistance, windowRect, screenHeight);
stimulus.RadiusPix = stimulus.DiamPix / 2;

% Create white disk texture (alpha-masked circle)
stimulus.Image = makeDiskImage(stimulus.DiamPix, [white white white]);
stimulus.Texture = Screen('MakeTexture', window, stimulus.Image);

% Motion parameters
% NOTE: speed and sweep distance are set PER TRIAL from the factorial design
% (design.speedsDva x design.eccDva). The stimulus reaches the flash point
% (= eccentricity) at the midpoint of a fixed design.sweepDur (s) sweep; travel
% is symmetric about that point:
%     half_travel_dva = speed * design.sweepDur/2
%     inner = ecc - half_travel ; outer = ecc + half_travel
% Per-trial pixel values are computed in the trial loop.

%% FLASH PARAMETERS (White disk, 1 DVA diameter) - flash baseline condition
flash.SizeDva = 1.0;
flash.SizePix = dva2pix(flash.SizeDva, eyeScreenDistance, windowRect, screenHeight);
flash.Rect = [0, 0, flash.SizePix, flash.SizePix];
% Flash/cue presentation duration: pinned to 4 frames.
% (At 120 Hz that is ~33.3 ms; expressed in frames so it is exact and does not
% drift with rounding. Change flash.presentFrames if a different count is wanted.)
flash.presentFrames = 4;

% Create white disk texture (alpha-masked circle)
flash.Image = makeDiskImage(flash.SizePix, [white white white]);
flash.Texture = Screen('MakeTexture', window, flash.Image);


% Pre-compute pixels per DVA for efficient runtime calculations
pixPerDva = dva2pix(1, eyeScreenDistance, windowRect, screenHeight);

% Pre-compute trigonometric constants (45 degrees is used throughout)
sin45 = sind(45);  % ~ 0.7071
cos45 = cosd(45);  % ~ 0.7071


%% CENTRAL CUE SETTINGS
% The central cue is a red disk at fixation (same 1 DVA shape as the stimulus
% and flash). It appears at the cue frame in the motion (centralcue) condition.
centralCueSizeDva = 1.0;  % Diameter of the disk cue (DVA)

%% CENTRAL CUE TEXTURE (created here after pixPerDva is defined)
centralCueSizePix = centralCueSizeDva * pixPerDva;
centralCueRect = [0, 0, centralCueSizePix, centralCueSizePix];
centralCueImage = makeDiskImage(centralCueSizePix, [white 0 0]);
centralCueTexture = Screen('MakeTexture', window, centralCueImage);
% Pre-compute centered rect for cue (always at fixation)
centralCueDestRect = CenterRectOnPoint(centralCueRect, xCenter, yCenter);

%% PROBE PARAMETERS (Gray disk, 1 DVA diameter; same for both conditions)
probe.SizeDva = 1.0;
probe.SizePix = dva2pix(probe.SizeDva, eyeScreenDistance, windowRect, screenHeight);
probe.Rect = [0, 0, probe.SizePix, probe.SizePix];

% Create gray disk probe texture (alpha-masked circle)
probe.Image = makeDiskImage(probe.SizePix, [grey grey grey]);
probe.Texture = Screen('MakeTexture', window, probe.Image);

probe.intervalTime = 0.5;
probe.intervalFrames = round(probe.intervalTime * refreshRate);

% Preload all textures to GPU
Screen('PreloadTextures', window);

%% GAZE MONITORING PARAMETERS
% Fixation must stay within this radius of screen centre during the trial.
gazeThresholdPix = dva2pix(3, eyeScreenDistance, windowRect, screenHeight);  % 3 DVA


%----------------------------------------------------------------------
%%                   GENERATE TRIAL STRUCTURE (INTERLEAVED)
%----------------------------------------------------------------------
% Trial row format (5 columns), shared by both conditions:
%   [ condition, quadrant, direction/timingMode, eccentricity_dva, speed_dva ]
%
%   condition            : 1 = centralcue (motion), 2 = flashbaseline (static)
%   direction/timingMode : -1 = petal (inward), +1 = fugal (outward)
%       MOTION  -> real stimulus motion direction
%       STATIC  -> timing mode (when the flash appears, mimicking petal/fugal)
%   speed_dva : stimulus speed in DVA/s (MOTION only; NaN for STATIC)
%
% One design-cycle = all 24 motion cells + all 8 static cells = 32 trials. Each block
% is built from whole design-cycles and shuffled, so motion and static trials are
% randomly interleaved within the block while every design cell appears an
% equal number of times per block.
%
% Quadrant is balanced WITHIN each block (evenly distributed, shuffled per
% block), NOT crossed as an experimental factor. The flash / stimulus sits ON
% the diagonal trajectory, so there is no left/right side factor.
%----------------------------------------------------------------------

nEcc     = length(design.eccDva);
nSpeed   = length(design.speedsDva);

% ---- Unique design cells, one row per cell: [cond, dir, ecc, speed] ----
motionCellSet = [];   % condition 1
for d = [-1, 1]
    for e = 1:nEcc
        for s = 1:nSpeed
            motionCellSet = [motionCellSet; 1, d, design.eccDva(e), design.speedsDva(s)];
        end
    end
end
staticCellSet = [];   % condition 2 (speed = NaN); tmode is a DUMMY 2x factor
%   (identical onsets for both values; kept only to fill the 32-trial design-cycle)
for tmode = [-1, 1]
    for e = 1:nEcc
        staticCellSet = [staticCellSet; 2, tmode, design.eccDva(e), NaN];
    end
end
cycleSet  = [motionCellSet; staticCellSet];   % one full design-cycle: 32 x 4
cycleSize = size(cycleSet, 1);                 % 32

%----------------------------------------------------------------------
%%                   SPLIT INTO BLOCKS
%----------------------------------------------------------------------
tpb = design.trialsPerBlock;
assert(mod(tpb, cycleSize) == 0, ...
    'trialsPerBlock (%d) must be a whole multiple of the %d-trial cycle.', tpb, cycleSize);
cyclesPerBlock = tpb / cycleSize;

numBlocks = design.numBlocks;
assert(isscalar(numBlocks) && numBlocks >= 1 && mod(numBlocks, 1) == 0, ...
    'design.numBlocks must be a positive integer (got %g).', numBlocks);
nTotalTrials       = numBlocks * tpb;
design.repsPerCell = nTotalTrials / cycleSize;   % DERIVED reps per design cell
fprintf('Design: %d blocks x %d trials/block = %d trials total (%d reps per design cell)\n', ...
    numBlocks, tpb, nTotalTrials, design.repsPerCell);

% ---- Build per-block trial matrices [cond, quad, dir, ecc, speed] ----
% Whole design-cycles per block, shuffled within block -> motion/static interleaved.
blockTrials = cell(numBlocks, 1);
for b = 1:numBlocks
    cells_b = repmat(cycleSet, cyclesPerBlock, 1);         % whole design-cycles
    cells_b = cells_b(randperm(size(cells_b, 1)), :);          % shuffle within block
    quad_b  = local_balancedQuadColumn(quadrants, size(cells_b, 1), 1);
    blockTrials{b} = [cells_b(:, 1), quad_b, cells_b(:, 2:4)];
end

% ---- Build the PRACTICE block trial matrix (same 5-column format) ----
% Not a design-cycle: it is a short random sample of the same cells, split to
% match the real 3:1 motion:static ratio so the participant sees both trial
% types. Never logged, so it does not need to be internally balanced.
nPractice = design.practiceTrials;
assert(isscalar(nPractice) && nPractice >= 0 && mod(nPractice, 1) == 0, ...
    'design.practiceTrials must be a non-negative integer (got %g).', nPractice);
practiceTrialList = zeros(0, 5);
if nPractice > 0
    nPracMotion = max(1, round(nPractice * 3/4));            % ~3:1, at least one
    nPracMotion = min(nPracMotion, nPractice - 1);           % leave room for >=1 static
    nPracStatic = nPractice - nPracMotion;
    % Sample with replacement only if more practice trials than unique cells.
    pickRows = @(setM, k) setM(local_samplePick(size(setM, 1), k), :);
    pracCells = [pickRows(motionCellSet, nPracMotion); pickRows(staticCellSet, nPracStatic)];
    pracCells = pracCells(randperm(size(pracCells, 1)), :);  % interleave the two types
    quad_p = local_balancedQuadColumn(quadrants, nPractice, 1);
    practiceTrialList = [pracCells(:, 1), quad_p, pracCells(:, 2:4)];
    fprintf('Practice block: %d trials (%d motion, %d static) - NOT logged\n', ...
        nPractice, nPracMotion, nPracStatic);
end

%----------------------------------------------------------------------
%%                   CONDITION LABELS / INSTRUCTIONS
%----------------------------------------------------------------------
% Condition 1 = centralcue (motion baseline)
% Condition 2 = flashbaseline (flash baseline)
% Both trial types are interleaved within every block, so a single combined
% instruction screen is shown at the start of each block.
conditionNames = {'centralcue', 'flashbaseline'};
blockInstruction = ...
    ['Each trial contains ONE of two events:\n\n' ...
     '1) A white disk moves diagonally and a red flash appears briefly in the \n' ...
     '    centre of the screen. Move the mouse to where the\n' ...
     '    white disk was when the flash appeared, and click to confirm.\n\n' ...
     '2) A white disk flashes briefly in the periphery,\n' ...
     '    together with a red flash in the centre of the screen. Move the mouse\n' ...
     '    to where the white disk appeared and click to confirm.\n\n' ...
     '    In all cases, simply move the mouse to where the white disk appeared\n' ...
     '    at the time of the red flash, and click to confirm.\n\n' ...
     'Keep your eyes on the fixation cross.'];

%----------------------------------------------------------------------
%%                   EYELINK / DATA FOLDER SETUP
%----------------------------------------------------------------------

% Create data folder (E3_DATA, alongside the stimulus folder)
data_folder = fullfile(fileparts(mfilename('fullpath')), 'E3_DATA');
if ~exist(data_folder, 'dir')
    mkdir(data_folder);
end

% EDF filename setup
subject_prefix = sbjname(1:min(3,length(sbjname)));
existing_files = dir(fullfile(data_folder, [subject_prefix, '*.edf']));
session_numbers = [];

for i = 1:length(existing_files)
    filename = existing_files(i).name;
    if length(filename) == 8 && strcmp(filename(end-3:end), '.edf')
        session_part = filename(4:5);
        if all(isstrprop(session_part, 'digit'))
            session_numbers = [session_numbers, str2double(session_part)];
        end
    end
end

if isempty(session_numbers)
    next_session = 1;
else
    next_session = max(session_numbers) + 1;
end

edf_name = sprintf('%s%02d', subject_prefix, next_session);
constants.eyelink_data_fname = [edf_name, '.edf'];
constants.eyelink_data_path = fullfile(data_folder, constants.eyelink_data_fname);

%----------------------------------------------------------------------
%%                       SOUND SETUP (must be BEFORE Eyelink for calibration beeps)
%----------------------------------------------------------------------
InitializePsychSound(1);
sampRate = 44100;
soundsFolder = fullfile(fileparts(mfilename('fullpath')), 'Sounds');

% Load success sound for experiment completion
correctoFile = fullfile(soundsFolder, 'correcto-100-mexicanos-dijeron.mp3');
[correctoSound, correctoFs] = audioread(correctoFile);
correctoSound = correctoSound';  % Transpose to row format for PsychPortAudio
if size(correctoSound, 1) == 1
    correctoSound = [correctoSound; correctoSound];  % Make stereo if mono
end
pahandle_correcto = PsychPortAudio('Open', [], [], 0, correctoFs, 2);
PsychPortAudio('FillBuffer', pahandle_correcto, correctoSound);

% Load tick sound for response confirmation
tickFile = fullfile(soundsFolder, 'tick.mp3');
[tickSound, tickFs] = audioread(tickFile);
tickSound = tickSound';
if size(tickSound, 1) == 1
    tickSound = [tickSound; tickSound];
end
pahandle_tick = PsychPortAudio('Open', [], [], 0, tickFs, 2);
PsychPortAudio('FillBuffer', pahandle_tick, tickSound);

% Low warning beep for gaze violations (synthesised: 220 Hz sine, 150 ms,
% 10 ms cosine on/off ramps to avoid onset/offset clicks)
beepDurSec = 0.15;
beepT = 0:1/sampRate:beepDurSec - 1/sampRate;
lowBeep = 0.5 * sin(2*pi*220*beepT);
beepRampN = round(0.01 * sampRate);
beepEnv = ones(size(lowBeep));
beepEnv(1:beepRampN) = 0.5 * (1 - cos(pi*(0:beepRampN-1)/beepRampN));
beepEnv(end-beepRampN+1:end) = fliplr(beepEnv(1:beepRampN));
lowBeep = lowBeep .* beepEnv;
pahandle_beep = PsychPortAudio('Open', [], [], 0, sampRate, 2);
PsychPortAudio('FillBuffer', pahandle_beep, [lowBeep; lowBeep]);

% Separate audio handle for Eyelink calibration sounds
pahandle_eyelink = PsychPortAudio('Open', [], [], 0, sampRate, 2);

% Initialize EyeLink
el = [];
eyeUsed = -1;
MISSING_DATA = -32768;

if isEyelink
    if EyelinkInit(0) ~= 1
        isEyelink = 0;
    else
        if Eyelink('OpenFile', constants.eyelink_data_fname) ~= 0
            Eyelink('Shutdown');
            isEyelink = 0;
        else
            el = EyelinkInitDefaults(window);
            el.calibrationtargetcolour = [255 255 255];
            el.calibrationtargetsize = 1.0;
            el.calibrationtargetwidth = 0.5;
            % Enable calibration beeps
            el.targetbeep = 1;
            el.feedbackbeep = 1;
            el.ppa_pahandle = pahandle_eyelink;  % Audio handle for calibration sounds
            Eyelink('command', 'calibration_area_proportion = 0.5 0.5');
            Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld', 0, 0, windowRect(3)-1, windowRect(4)-1);
            Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
            Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
            Eyelink('Command', 'file_sample_data = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS');
            Eyelink('Command', 'link_sample_data = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');
            Eyelink('Command', 'set_idle_mode');
            Eyelink('Command', 'clear_screen 0');
            EyelinkUpdateDefaults(el);
            EyelinkDoTrackerSetup(el);
            Eyelink('Command', 'set_idle_mode');
        end
    end
else
    fprintf('*** EYELINK DISABLED (isEyelink = 0) - No eye tracking ***\n');
end

if isEyelink
    Eyelink('Command', 'set_idle_mode');
    Eyelink('Command', 'clear_screen 0');
    Eyelink('StartRecording');
    eyeUsed = Eyelink('EyeAvailable');
    if eyeUsed == 2
        eyeUsed = 1;
    end
    Eyelink('message', 'SYNCTIME');
end

% Define confirmQuit as a nested function handle
confirmQuit = @() confirmQuitDialog(window, white, grey, black);

%----------------------------------------------------------------------
%%                   INITIALIZE DATA STORAGE
%----------------------------------------------------------------------
csv_data = [];
csv_trial_counter = 0;  % Counter for VALID trials only
csvDirty = false;       % set true when new trial rows are pending a disk write

% Create CSV filename now for incremental saving (crash-safe)
time_start = clock;
csv_filename = sprintf('%s_FLE_E3_%04d_%02d_%02d_%02d_%02d.csv', ...
    sbjname, time_start(1), time_start(2), time_start(3), time_start(4), time_start(5));
csv_filepath = fullfile(data_folder, csv_filename);

% Flush helper: the local function local_flushCSV (defined at end of file) is
% called directly at block boundaries and on every exit path, NOT every trial,
% so the file is rewritten ~once per block instead of once per trial. csv_data
% is passed live at each call so the latest rows are always written. (We call
% the local function directly rather than via an anonymous handle, which would
% capture csv_data by value at definition time, when it is still empty.)

% TIMING subfolder + per-session frame-interval accumulator for the timing
% report (frame-length histogram + summary), written as a PDF at session end.
timing_folder = fullfile(data_folder, 'TIMING');
if ~exist(timing_folder, 'dir')
    mkdir(timing_folder);
end
[~, csv_base, ~] = fileparts(csv_filename);
timing_pdf_filepath = fullfile(timing_folder, [csv_base '_timing.pdf']);
allFrameIntervalsMs = [];   % every stimulus-phase mid-animation frame interval (ms)

csv_header = {'version', 'block', 'trial', 'condition', 'valid', 'motion_direction', ...
    'quadrant', 'eccentricity_dva', ...
    'speed_dva', 'flash_onset_frame', 'flash_onset_ms', ...
    'flash_frames', 'target_dva', 'target_x_dva', 'target_y_dva', ...
    'probe_initial', 'probe_dva', 'probe_x_dva', 'probe_y_dva', ...
    'foveal_offset', 'temporal_error_ms', 'x_offset', 'y_offset', ...
    'measured_fps', 'stim_skipped_frames', 'stim_mean_frame_ms', ...
    'stim_worst_frame_ms', 'stim_dur_error_ms', 'cue_onset_error_ms', ...
    'rt_ms', 'rng_seed'};

%======================================================================
%%                        MAIN EXPERIMENT LOOP
%======================================================================

%----------------------------------------------------------------------
%   WARM-UP PASS (eliminates first-trial cursor lag)
%----------------------------------------------------------------------
% The first call to GetMouse/SetMouse/DrawTexture/DrawFormattedText and the
% first real use of the audio engine each incur a one-time initialisation
% latency. Without this, that cost lands on trial 1's response phase, making
% the cursor glitchy and slow to move. Here we exercise every such call for a
% few frames on a blank screen (never shown as a real trial) so the warm-up
% cost is paid up front and trial 1 behaves like every other trial.
warmupFrames = round(0.5 * refreshRate);   % ~0.5 s of priming
[wmX, wmY] = RectCenter(windowRect);
for wf = 1:warmupFrames
    [mx, my, mb, ~, wv] = GetMouse(window);   % prime mouse + valuator read
    Screen('FillRect', window, black);
    wmRect = CenterRectOnPoint(probe.Rect, wmX, wmY);
    Screen('DrawTexture', window, probe.Texture, [], wmRect, 0, [], [], [grey grey grey]);
    Screen('TextSize', window, 16);
    DrawFormattedText(window, ' ', 'center', windowRect(4) - 40, black);  % prime text engine
    Screen('DrawingFinished', window);
    Screen('Flip', window);
end
% Prime the audio engine (silent: start then immediately stop)
try
    PsychPortAudio('Start', pahandle_tick, 1, 0, 0);
    PsychPortAudio('Stop', pahandle_tick, 1);
catch
end
% Clear to black and flush input before the first block
Screen('FillRect', window, black);
Screen('Flip', window);
KbReleaseWait();

% Block 0 is the PRACTICE block (unlogged warm-up); blocks 1..numBlocks are
% the real, logged experiment. If design.practiceTrials is 0 the practice
% block is skipped entirely and the loop starts at block 1 as before.
if design.practiceTrials > 0
    firstBlockIdx = 0;
else
    firstBlockIdx = 1;
end

for blockIdx = firstBlockIdx:numBlocks

    isPractice = (blockIdx == 0);

    if isPractice
        trials = practiceTrialList;
        fprintf('\n=== PRACTICE BLOCK (%d trials, no data logged; SPACE to end early) ===\n', ...
            size(trials, 1));
    else
        trials = blockTrials{blockIdx};
    end
    numTrials = size(trials, 1);

    % Set true when SPACE is pressed during practice; ends the practice block
    % at the next safe point and jumps to the "begin experiment" screen.
    practiceSkipRequested = false;

    %------------------------------------------------------------------
    %                    INSTRUCTION SCREEN (FIRST BLOCK ONLY)
    %------------------------------------------------------------------
    % Shown once, before the FIRST block that runs - the practice block when
    % one is enabled, otherwise block 1. Later blocks flow straight from the
    % rest screen's click-to-continue into the pre-trial fixation pause.
    % This screen also performs the macOS cursor-control handover (see the
    % click comment below), so it must stay on whichever block runs first.
    % The screen is REDRAWN AND FLIPPED every loop iteration (not drawn once
    % and left up): on Apple Silicon macOS, pauses of > 1 s between flips can
    % cause stutter / flip-timeout warnings on the next scheduled flip
    % (PTB 3.0.22.x release notes), so the flip cadence is kept alive during
    % this indefinite wait.
    if blockIdx == firstBlockIdx
        Screen('TextSize', window, 40);
        Screen('TextFont', window, 'Futura');
        if isPractice
            instructionText = [blockInstruction, ...
                '\n\nWe will start with a short practice run.\n' ...
                '\n\n\nClick anywhere to begin.'];
        else
            instructionText = [blockInstruction, ...
                '\n\n\nClick anywhere to begin.'];
        end

        % CLICK (not keypress) to begin, deliberately: on macOS the first
        % click inside the fullscreen window hands it cursor control - until
        % then HideCursor is ignored. This moves that handover before trial 1.
        KbReleaseWait();
        waiting = true;
        while waiting
            HideCursor(screenNumber);
            Screen('FillRect', window, black);
            DrawFormattedText(window, instructionText, 'center', 'center', white);
            Screen('Flip', window);
            [~, ~, instrButtons] = GetMouse(window);
            if any(instrButtons)
                waiting = false;
            end
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyIsDown && keyCode(escapeKey)
                if confirmQuit()
                    quitCleanup(csv_filepath, csv_data, csv_header, timing_pdf_filepath, ...
                        allFrameIntervalsMs, csv_filename, sbjname, time_start, refreshRate, ...
                        ifi, measuredRefreshRate, csv_trial_counter, numBlocks, ...
                        originalAlertVolume, isEyelink);
                    return;
                end
                KbReleaseWait();
            end
        end
        % Wait for the click to be released
        while any(instrButtons)
            [~, ~, instrButtons] = GetMouse(window);
        end
        KbReleaseWait();

        % The click just gave the window cursor control, so hiding works
        % from here on. Toggle Show->Hide ONCE to reset PTB's internal
        % "already hidden" flag - a bare HideCursor would no-op on it and
        % leave the parked arrow visible all session. (No SetMouse here: the
        % cursor is frozen so it never moved, and a warp would itself be a
        % re-reveal trigger.)
        ShowCursor(screenNumber);
        HideCursor(screenNumber);
    end

    if isEyelink
        if isPractice
            Eyelink('Message', 'PRACTICE_BLOCK');
        else
            Eyelink('Message', 'BLOCK %d', blockIdx);
        end
    end

    % Brief pause before first trial (no user input needed)
    Screen('FillRect', window, black);
    Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
    Screen('Flip', window);
    WaitSecs(0.5);

    %------------------------------------------------------------------
    %   INITIALIZE PER-BLOCK INVALID TRIAL QUEUE
    %------------------------------------------------------------------
    invalidTrialsQueue = [];  % Will store structs of trials to repeat
    maxRepeatAttempts = 3;    % Safety to avoid infinite looping if fixation impossible
    numTrialsThisBlock = numTrials;  % Will increase as invalid trials are queued
    trialAttemptCount = ones(1, numTrials);  % Track attempt count for each trial (starts at 1)

    %------------------------------------------------------------------
    %                    TRIAL LOOP (while loop for repeat support)
    %------------------------------------------------------------------

    trial = 1;
    while trial <= numTrialsThisBlock

        %--------------------------------------------------------------
        %                FIXATE + 3-2-1 COUNTDOWN TO BEGIN TRIAL
        %--------------------------------------------------------------
        % Probe start position: random 50/50 (fixation vs peripheral) per trial.
        % Kept random by design so a post-hoc test can confirm start position
        % has no significant effect on the adjusted setting. Logged as
        % probe_initial so the analysis can condition on it.
        probeStartsAtFixation = rand() < 0.5;

        KbReleaseWait();

        % 3-2-1 countdown with gaze checking
        countdownNumbers = {'3', '2', '1'};
        countdownDuration = 0.5;  % seconds per number

        countIdx = 1;
        while countIdx <= 3
            countdownStartTime = GetSecs();
            countdownViolated = false;

            while (GetSecs() - countdownStartTime) < countdownDuration
                % Check gaze if eye tracking is enabled
                gazeOK = true;  % Default OK if no eye tracking
                if isEyelink
                    evt = Eyelink('NewestFloatSample');
                    if isstruct(evt) && eyeUsed ~= -1 && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                        eyeX = evt.gx(eyeUsed + 1);
                        eyeY = evt.gy(eyeUsed + 1);
                        if eyeX ~= MISSING_DATA && eyeY ~= MISSING_DATA && ~isnan(eyeX) && ~isnan(eyeY)
                            gazeDistFromFix = hypot(eyeX - xCenter, eyeY - yCenter);
                            gazeOK = gazeDistFromFix < gazeThresholdPix;
                        else
                            % Missing eye data = treat as violation (eyes removed from tracker)
                            gazeOK = false;
                        end
                    else
                        % No valid sample structure = treat as violation
                        gazeOK = false;
                    end
                end

                % Draw fixation cross with countdown number behind it
                HideCursor(screenNumber);   % keep the arrow gone pre-trial
                Screen('FillRect', window, black);
                Screen('TextSize', window, 100);

                % Show countdown or gaze warning
                if gazeOK
                    % Calculate fade: starts bright, fades to darker during each number
                    elapsedRatio = (GetSecs() - countdownStartTime) / countdownDuration;
                    elapsedRatio = min(1, max(0, elapsedRatio));  % Clamp 0-1
                    fadeBrightness = grey * (1.0 - 0.6 * elapsedRatio);  % Fade from grey to ~40% grey

                    % Draw large countdown number with fading brightness
                    DrawFormattedText(window, countdownNumbers{countIdx}, 'center', 'center', fadeBrightness);
                else
                    % Gaze violation - will reset countdown to 3
                    Screen('TextSize', window, 50);
                    DrawFormattedText(window, 'Hold fixation to continue', 'center', yCenter - 60, red);
                    countdownViolated = true;
                end

                % Always draw fixation cross on top
                Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                Screen('Flip', window);

                % Check for escape
                [keyIsDown, ~, keyCode] = KbCheck();
                if keyIsDown
                    if keyCode(escapeKey)
                        if confirmQuit()
                            quitCleanup(csv_filepath, csv_data, csv_header, timing_pdf_filepath, ...
                                allFrameIntervalsMs, csv_filename, sbjname, time_start, refreshRate, ...
                                ifi, measuredRefreshRate, csv_trial_counter, numBlocks, ...
                                originalAlertVolume, isEyelink);
                            return;
                        end
                        KbReleaseWait();
                    elseif isPractice && keyCode(spaceKey)
                        % SPACE ends the practice block early. Flag it and unwind
                        % out of the countdown; the trial loop breaks below.
                        practiceSkipRequested = true;
                        break;
                    end
                end

                % Flush any mouse clicks during this phase
                [~, ~, buttons] = GetMouse(window);
            end

            if practiceSkipRequested
                break;
            end

            % After this countdown step: reset to 3 if violated, else advance
            if countdownViolated
                countIdx = 1;  % Reset to '3'
            else
                countIdx = countIdx + 1;  % Advance to next number
            end
        end

        % SPACE pressed during the countdown: leave the practice trial loop now,
        % before any stimulus is shown.
        if practiceSkipRequested
            break;
        end

        % Reset background color and gaze tracking
        backgroundColor = black;
        gazeViolationDuringMotion = false;
        fixationOutside2DVA_prev = false;  % Track previous state for sound edge detection

        % Get trial parameters (condition is per TRIAL: interleaved design)
        currentCondition = trials(trial, 1);       % 1=centralcue, 2=flashbaseline
        currentConditionName = conditionNames{currentCondition};
        quad = trials(trial, 2);
        motionDir = trials(trial, 3);      % -1=petal, +1=fugal (timing mode for flash baseline)
        eccDva = trials(trial, 4);         % Eccentricity in DVA (= flash point)
        speedDva = trials(trial, 5);       % Stimulus speed DVA/s (motion); NaN for static

        % Flash/target eccentricity (no jitter in this design)
        flashEccDva = eccDva;
        % Exact dva2pix conversion (NOT the linear pixPerDva approximation) so
        % the drawn flash position is the exact inverse of the pix2dva used on
        % responses; a tan-based dva2pix with linear drawing would create an
        % eccentricity-dependent artifact in the logged offsets.
        flashEccPix = dva2pix(eccDva, eyeScreenDistance, windowRect, screenHeight);

        % Per-trial speed (motion condition only).
        % Option A: the stimulus moves at a CONSTANT speed in DVA (10/15/20 dva/s),
        % so it passes through the flash point (= ecc) at exactly the sweep
        % midpoint for both directions, independent of eccentricity. Position is
        % tracked in DVA and converted to pixels each frame for drawing only.
        % (Previously speed was a single dva2pix() of the speed number, giving
        % constant PIXELS/frame -> nonlinear dva/s -> fugal/petal onset asymmetry.)
        if currentCondition == 1
            stimulus.speedDvaPerFrame = speedDva / refreshRate;   % constant dva per frame

            % Symmetric sweep about the flash point: half-travel = speed * sweepDur/2
            halfTravelDva         = speedDva * design.sweepDur / 2;
            stimulus.startDistDva = eccDva - halfTravelDva;   % inner edge
            stimulus.endDistDva   = eccDva + halfTravelDva;   % outer edge
            stimulus.movDistDva   = stimulus.endDistDva - stimulus.startDistDva;   % = 2*halfTravel
        end


        %--------------------------------------------------------------
        %                QUADRANT-SPECIFIC SETUP
        %--------------------------------------------------------------
        if quad == 45        % Upper-right
            phaseshiftFactorX = 1;
            phaseshiftFactorY = -1;
        elseif quad == 135   % Upper-left
            phaseshiftFactorX = -1;
            phaseshiftFactorY = -1;
        elseif quad == 225   % Lower-left
            phaseshiftFactorX = -1;
            phaseshiftFactorY = 1;
        elseif quad == 315   % Lower-right
            phaseshiftFactorX = 1;
            phaseshiftFactorY = 1;
        end

        %--------------------------------------------------------------
        %                SHOW FIXATION
        %--------------------------------------------------------------
        % Ensure cursor stays hidden during trial
        HideCursor(screenNumber);

        Screen('FillRect', window, black);
        Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
        fixationStartTime = Screen('Flip', window);

        while GetSecs() - fixationStartTime < fixDuration
            % Check for ESC key to quit
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyIsDown && keyCode(escapeKey)
                if confirmQuit()
                    quitCleanup(csv_filepath, csv_data, csv_header, timing_pdf_filepath, ...
                        allFrameIntervalsMs, csv_filename, sbjname, time_start, refreshRate, ...
                        ifi, measuredRefreshRate, csv_trial_counter, numBlocks, ...
                        originalAlertVolume, isEyelink);
                    return;
                end
                % Reset fixation timing after confirmation cancelled
                fixationStartTime = GetSecs();
            elseif keyIsDown && isPractice && keyCode(spaceKey)
                practiceSkipRequested = true;
                break;
            end

            % Gaze monitoring during fixation - always try to get newest sample (more reliable)
            if isEyelink
                evt = Eyelink('NewestFloatSample');
                if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                    gx = evt.gx(eyeUsed+1);
                    gy = evt.gy(eyeUsed+1);
                    if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                        gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                        if gazeDistPix > gazeThresholdPix
                            gazeViolationDuringMotion = true;  % Invalidate trial for fixation violations
                        end
                    else
                        % Missing eye data = treat as violation (eyes removed from tracker)
                        gazeViolationDuringMotion = true;
                    end
                else
                    % No valid sample structure = treat as violation
                    gazeViolationDuringMotion = true;
                end
            end
            Screen('FillRect', window, black);
            Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
            Screen('Flip', window);
        end

        % SPACE pressed during the fixation hold: end practice before the
        % stimulus is presented.
        if practiceSkipRequested
            break;
        end

        if isEyelink
            Eyelink('Message', 'TRIALID %d', trial);
        end

        %--------------------------------------------------------------
        %                STIMULUS PRESENTATION
        %--------------------------------------------------------------

        % Initialize variables
        flashFrameCounter = 0;
        stimLocAtCueX = NaN;
        stimLocAtCueY = NaN;
        flashLocX = NaN;
        flashLocY = NaN;

        %------------------------------------------------------------------
        % FLASH / CUE ONSET FRAME COMPUTATION
        %------------------------------------------------------------------
        % With constant-DVA motion (Option A) the stimulus reaches the flash point
        % (= ecc) after exactly sweepDur/2 seconds for BOTH directions and ALL
        % eccentricities. So the onset frame is the sweep midpoint, identical for
        % petal and fugal, with an optional small lead so the flash is fully
        % visible by the time the stimulus arrives.
        flashDurationFrames = flash.presentFrames;
        flashLeadFrames = round(0.014 * refreshRate);  % ~14 ms lead (2 frames = 16.7 ms @120Hz)

        % midpointFrame: the frame on which the stimulus is at the flash point.
        % Frame f draws the stimulus after (f-1) increments from the start edge, so the
        % stimulus is at ecc when (f-1)*dvaPerFrame == halfTravel  ->  f = midpoint+1.
        midpointFrame   = round((design.sweepDur/2) * refreshRate) + 1;
        flashOnsetFrame = max(1, midpointFrame - flashLeadFrames);

        % The flash/cue window must fit inside the (sweepDur-long) trial; both
        % conditions now share this duration.
        assert(flashOnsetFrame + flashDurationFrames - 1 <= round(design.sweepDur * refreshRate), ...
            'Flash window (frames %d..%d) exceeds the %d-frame trial.', flashOnsetFrame, ...
            flashOnsetFrame + flashDurationFrames - 1, round(design.sweepDur * refreshRate));


        % Animation loop
        if currentCondition == 2  % flashbaseline - flash alone
            %----------------------------------------------------------
            % FLASH BASELINE: Flash only, no moving stimulus
            % Uses same timing as motion conditions (flashOnsetFrame)
            %----------------------------------------------------------
            % Trial duration MATCHED to the motion sweep (design.sweepDur) so
            % the flash-to-response delay is identical across conditions.
            % (Was 1 s, giving static trials an extra 0.5 s retention interval.)
            totalFrames = round(design.sweepDur * refreshRate);

            % Flash sits directly ON the diagonal trajectory at the target
            % eccentricity (no perpendicular offset).
            flashLocX = xCenter + phaseshiftFactorX * flashEccPix * sin45;
            flashLocY = yCenter + phaseshiftFactorY * flashEccPix * cos45;
            flashRect = CenterRectOnPoint(flash.Rect, flashLocX, flashLocY);

            % Initialize VBL for scheduled flips (draw fixation to prevent blank frame)
            Screen('FillRect', window, backgroundColor);
            Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
            vbl = Screen('Flip', window);

            % Per-frame VBL timestamps for stimulus-phase frame diagnostics.
            stimVBL = zeros(1, totalFrames);

            for frame = 1:totalFrames
                Screen('FillRect', window, backgroundColor);

                % Flash ON from flashOnsetFrame for exactly flashDurationFrames (4 frames)
                isFlashWindow = (frame >= flashOnsetFrame) && (frame < flashOnsetFrame + flashDurationFrames);

                if isFlashWindow
                    Screen('DrawTexture', window, flash.Texture, [], flashRect);
                    flashFrameCounter = flashFrameCounter + 1;

                    if isEyelink && flashFrameCounter == 1
                        Eyelink('Message', 'FLASH');
                    end
                end

                % Fixation: red disk cue during the flash window (matched to the
                % motion condition's central cue), else the white cross.
                if isFlashWindow
                    Screen('DrawTexture', window, centralCueTexture, [], centralCueDestRect);
                else
                    Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                end
                Screen('DrawingFinished', window);
                vbl = Screen('Flip', window, vbl + 0.5*ifi);  % Schedule half-frame ahead
                stimVBL(frame) = vbl;

                % Gaze monitoring - always try to get newest sample (more reliable)
                if isEyelink
                    evt = Eyelink('NewestFloatSample');
                    eyeDataMissing = true;  % Assume missing until proven otherwise
                    if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                        gx = evt.gx(eyeUsed+1);
                        gy = evt.gy(eyeUsed+1);
                        if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                            eyeDataMissing = false;
                            gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                            outside2 = gazeDistPix > gazeThresholdPix;

                            if outside2
                                gazeViolationDuringMotion = true;
                            end

                            if outside2 && ~fixationOutside2DVA_prev
                                % Gaze violation: invalidate and exit. (Warning
                                % beep intentionally NOT played here -- a mid-loop
                                % PsychPortAudio Start/Stop can block for ms and
                                % drop frames. It plays in the violation-handling
                                % block after the loop exits.)
                                break;  % Exit the animation loop
                            end

                            fixationOutside2DVA_prev = outside2;
                        end
                    end
                    % Missing eye data = treat as violation (eyes removed from tracker)
                    if eyeDataMissing
                        gazeViolationDuringMotion = true;
                        fprintf('  [GAZE VIOLATION during stimulus - trial invalidated]\n');
                        break;
                    end
                end
            end

        else  % Central cue (condition 1)
            %----------------------------------------------------------
            % CENTRAL CUE: Moving stimulus with a central cue (no peripheral flash)
            % Stimulus moves; central cue appears at fixation at the pre-computed frame.
            % Observer reports where the stimulus was at the time of the cue.
            %----------------------------------------------------------

            % Set initial stimulus position (in DVA) based on motion direction
            if motionDir == 1  % Fugal (outward): start inner
                stimDistDva = stimulus.startDistDva;
            else  % Petal (inward): start outer
                stimDistDva = stimulus.endDistDva;
            end

            totalFrames = round(stimulus.movDistDva / stimulus.speedDvaPerFrame);

            % Pre-compute trajectory multipliers
            trajMultX = phaseshiftFactorX * sin45;
            trajMultY = phaseshiftFactorY * cos45;

            % Initialize VBL for scheduled flips (draw fixation to prevent blank frame)
            Screen('FillRect', window, backgroundColor);
            Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
            vbl = Screen('Flip', window);

            % Per-frame VBL timestamps for stimulus-phase frame diagnostics.
            stimVBL = zeros(1, totalFrames);

            for frame = 1:totalFrames
                Screen('FillRect', window, backgroundColor);

                % Convert this frame's DVA position to pixels for drawing via
                % the exact dva2pix conversion, so drawing and response read-out
                % (pix2dva) are exact inverses regardless of whether dva2pix is
                % linear or tan-based. One dva2pix call per frame costs
                % microseconds - safely inside the 10 ms frame budget.
                stimDistPix = dva2pix(stimDistDva, eyeScreenDistance, windowRect, screenHeight);

                % Calculate stimulus center position for this frame
                stimCenterX = xCenter + trajMultX * stimDistPix;
                stimCenterY = yCenter + trajMultY * stimDistPix;

                stimRect = [stimCenterX - stimulus.RadiusPix, stimCenterY - stimulus.RadiusPix, ...
                            stimCenterX + stimulus.RadiusPix, stimCenterY + stimulus.RadiusPix];

                % Draw moving stimulus
                Screen('DrawTexture', window, stimulus.Texture, [], stimRect);

                % Cue ON from flashOnsetFrame for flashDurationFrames
                isFlashWindow = (frame >= flashOnsetFrame) && (frame < flashOnsetFrame + flashDurationFrames);

                % Send EyeLink message on first cue frame
                if frame == flashOnsetFrame
                    if isEyelink
                        Eyelink('Message', 'FIXCUE');
                    end
                end

                % Store the stimulus position on the MIDPOINT frame: the frame on
                % which the stimulus is exactly at the flash point (ecc). This makes
                % the recorded target position correspond to target_dva = ecc and
                % to the temporal-error reference, rather than the last cue frame
                % (which is a few frames of travel beyond ecc).
                if frame == midpointFrame
                    stimLocAtCueX = stimCenterX;
                    stimLocAtCueY = stimCenterY;
                end

                % Count cue frames (for CSV)
                if isFlashWindow
                    flashFrameCounter = flashFrameCounter + 1;
                end

                % Draw fixation (red disk cue during the cue window, else cross)
                if isFlashWindow
                    Screen('DrawTexture', window, centralCueTexture, [], centralCueDestRect);
                else
                    Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                end

                Screen('DrawingFinished', window);
                vbl = Screen('Flip', window, vbl + 0.5*ifi);  % Schedule half-frame ahead
                stimVBL(frame) = vbl;

                % Gaze monitoring - always try to get newest sample (more reliable)
                if isEyelink
                    evt = Eyelink('NewestFloatSample');
                    eyeDataMissing = true;  % Assume missing until proven otherwise
                    if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                        gx = evt.gx(eyeUsed+1);
                        gy = evt.gy(eyeUsed+1);
                        if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                            eyeDataMissing = false;
                            gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                            outside2 = gazeDistPix > gazeThresholdPix;

                            if outside2
                                gazeViolationDuringMotion = true;
                            end

                            if outside2 && ~fixationOutside2DVA_prev
                                % Gaze violation: invalidate and exit. (Warning
                                % beep intentionally NOT played here -- a mid-loop
                                % PsychPortAudio Start/Stop can block for ms and
                                % drop frames. It plays in the violation-handling
                                % block after the loop exits.)
                                fprintf('  [GAZE VIOLATION during stimulus - trial invalidated]\n');
                                break;  % Exit the animation loop
                            end

                            fixationOutside2DVA_prev = outside2;
                        end
                    end
                    % Missing eye data = treat as violation (eyes removed from tracker)
                    if eyeDataMissing
                        gazeViolationDuringMotion = true;
                        fprintf('  [GAZE VIOLATION during stimulus - trial invalidated]\n');
                        break;
                    end
                end

                % Update stimulus position (in DVA) for next frame at constant dva/s
                stimDistDva = stimDistDva + motionDir * stimulus.speedDvaPerFrame;
            end
        end

        %--------------------------------------------------------------
        %   STIMULUS-PHASE FRAME DIAGNOSTICS (from captured VBL stamps)
        %--------------------------------------------------------------
        % stim_mean_frame_ms   : mean frame interval (ms) over frames that ran
        % measured_fps         : 1000 / stim_mean_frame_ms (derived from the same
        %                        mean, so the two columns can never disagree)
        % stim_skipped_frames  : # mid-animation intervals longer than 1.5 x ifi
        % stim_worst_frame_ms  : longest mid-animation frame interval (ms)
        % stim_dur_error_ms    : actual stimulus duration - expected (ms)
        %                        expected = (nFrames-1) * ifi
        % cue_onset_error_ms   : actual cue/flash onset - intended onset (ms)
        %                        intended = (flashOnsetFrame-1) * ifi from stim start
        % NOTE: the FIRST inter-frame interval is excluded from the worst-frame
        % and skipped-frame measures. The first drawn frame always carries some
        % one-time per-trial setup cost (~14 ms) that is not a dropped frame and
        % is not visible during the sweep; including it made every trial look
        % like it had a ~14 ms "worst frame". Mean/duration/onset still use all
        % frames, since those want the full timeline.
        % Computed only over frames that actually ran (a gaze-violation break can
        % leave preallocated trailing zeros in stimVBL).
        stimWorstFrameMs = NaN; stimDurErrorMs = NaN; cueOnsetErrorMs = NaN;
        flashOnsetVBL = NaN;   % absolute GetSecs timestamp of flash onset (for RT)
        if exist('stimVBL', 'var') && any(stimVBL > 0)
            ranVBL = stimVBL(stimVBL > 0);
            if numel(ranVBL) >= 2
                frameIntervals = diff(ranVBL);                 % seconds
                stimMeanFrameMs = mean(frameIntervals) * 1000;
                measuredFps     = 1000 / stimMeanFrameMs;      % from the mean, not median-reciprocal
                % Mid-animation intervals exclude the first (setup-contaminated) one.
                if numel(frameIntervals) >= 2
                    midIntervals = frameIntervals(2:end);
                else
                    midIntervals = frameIntervals;             % too short to trim
                end
                stimSkippedFrames = sum(midIntervals > 1.5 * ifi);
                stimWorstFrameMs  = max(midIntervals) * 1000;
                % Accumulate mid-animation intervals (ms) for the session timing
                % report's frame-length histogram. Practice trials are excluded
                % so the report describes the logged experiment only.
                if ~isPractice
                    allFrameIntervalsMs = [allFrameIntervalsMs, midIntervals * 1000];
                end
                % Duration error: actual elapsed vs expected for the frames run.
                actualDurMs   = (ranVBL(end) - ranVBL(1)) * 1000;
                expectedDurMs = (numel(ranVBL) - 1) * ifi * 1000;
                stimDurErrorMs = actualDurMs - expectedDurMs;
                % Cue/flash onset error: only if the onset frame actually ran.
                if flashOnsetFrame >= 1 && flashOnsetFrame <= numel(stimVBL) ...
                        && stimVBL(flashOnsetFrame) > 0
                    actualOnsetMs   = (stimVBL(flashOnsetFrame) - stimVBL(1)) * 1000;
                    intendedOnsetMs = (flashOnsetFrame - 1) * ifi * 1000;
                    cueOnsetErrorMs = actualOnsetMs - intendedOnsetMs;
                    flashOnsetVBL   = stimVBL(flashOnsetFrame);  % GetSecs clock, for RT
                end
            else
                stimMeanFrameMs = NaN; measuredFps = NaN; stimSkippedFrames = 0;
            end
        else
            stimMeanFrameMs = NaN; measuredFps = NaN; stimSkippedFrames = NaN;
        end
        clear stimVBL;  % avoid carrying stale stamps into a trial that breaks early

        % Check for NaN target locations (stimulus loop exited abnormally)
        if currentCondition == 2   % flashbaseline -> localizing flash
            if isnan(flashLocX) || isnan(flashLocY)
                gazeViolationDuringMotion = true;
            end
        else                       % centralcue -> localizing stimulus
            if isnan(stimLocAtCueX) || isnan(stimLocAtCueY)
                gazeViolationDuringMotion = true;
            end
        end

        %--------------------------------------------------------------
        %      HANDLE GAZE VIOLATION: Silent invalidation, continue to next trial
        %--------------------------------------------------------------
        if gazeViolationDuringMotion
            % Low warning beep. Safe to play HERE (not inside the animation
            % loop, where PsychPortAudio Start/Stop can block and drop frames):
            % the stimulus loop has already exited and the trial is invalid.
            PsychPortAudio('Stop', pahandle_beep);
            PsychPortAudio('Start', pahandle_beep, 1, 0, 0);

            % Brief pause before next trial
            WaitSecs(0.1);

            % Set response values to NaN for invalid trial
            probeDisplayDva = NaN;
            totalOffsetDva = NaN;
            probeInitialText = 'NA';  % char, matching 'centre'/'edge' (writetable
                                      % requires type-homogeneous cell columns)

            % Target DVA is flashEccDva for all conditions
            targetDva = flashEccDva;

            % Build trial info string for invalid trial (same format as valid)
            flashEccDva_log = flashEccDva;  % Use theoretical value directly
            flashOnsetTime_ms = ((flashOnsetFrame - 1) / refreshRate) * 1000;   % frame f flips (f-1)*ifi after sweep start

            switch quad
                case 45
                    quadName = 'UPPER RIGHT';
                case 135
                    quadName = 'UPPER LEFT';
                case 225
                    quadName = 'LOWER LEFT';
                case 315
                    quadName = 'LOWER RIGHT';
            end

            if motionDir == 1
                motionText_display = 'FUGAL';
            elseif motionDir == -1
                motionText_display = 'PETAL';
            else
                motionText_display = '';
            end

            if currentCondition == 1
                condDisplay = 'CENTRAL CUE';
            else
                condDisplay = 'FLASH BL';
            end

            % Queue trial for repetition at end of block (with attempt tracking)
            currentAttempt = trialAttemptCount(trial);

            if currentAttempt < maxRepeatAttempts
                queuedTrial.cond = currentCondition;
                queuedTrial.quad = quad;
                queuedTrial.motionDir = motionDir;
                queuedTrial.eccDva = eccDva;
                queuedTrial.speedDva = speedDva;
                queuedTrial.attemptCount = currentAttempt + 1;  % Next attempt number
                invalidTrialsQueue = [invalidTrialsQueue, queuedTrial];
                trialAttemptCount(trial) = trialAttemptCount(trial) + 1;  % Mark this trial as attempted

                if currentCondition == 1  % central cue
                    fprintf('B%d T--: %s | %s | %s | CUE @ %.0fdva | SPEED %.0f/s | ONSET @ %.0fms | INVALID (attempt %d/%d)\n', ...
                        blockIdx, condDisplay, motionText_display, quadName, ...
                        flashEccDva_log, speedDva, flashOnsetTime_ms, currentAttempt, maxRepeatAttempts);
                else  % flash baseline
                    fprintf('B%d T--: %s | %s | FLASH @ %.0fdva | ONSET @ %.0fms | INVALID (attempt %d/%d)\n', ...
                        blockIdx, condDisplay, quadName, ...
                        flashEccDva_log, flashOnsetTime_ms, currentAttempt, maxRepeatAttempts);
                end
            else
                % Max attempts reached - print with FAILED
                if currentCondition == 1  % central cue
                    fprintf('B%d T%d: %s | %s | %s | CUE @ %.0fdva | SPEED %.0f/s | ONSET @ %.0fms | FAILED (max attempts)\n', ...
                        blockIdx, trial, condDisplay, motionText_display, quadName, ...
                        flashEccDva_log, speedDva, flashOnsetTime_ms);
                else  % flash baseline
                    fprintf('B%d T%d: %s | %s | FLASH @ %.0fdva | ONSET @ %.0fms | FAILED (max attempts)\n', ...
                        blockIdx, trial, condDisplay, quadName, ...
                        flashEccDva_log, flashOnsetTime_ms);
                end
            end
        else
            %--------------------------------------------------------------
            %                RESPONSE COLLECTION (Method of Adjustment)
            %--------------------------------------------------------------

            % Print trial info BEFORE response
            flashEccDva_log = pix2dva(flashEccPix, eyeScreenDistance, windowRect, screenHeight);
            flashOnsetTime_ms = ((flashOnsetFrame - 1) / refreshRate) * 1000;   % frame f flips (f-1)*ifi after sweep start

            % Format quadrant as position name
            switch quad
                case 45
                    quadName = 'UPPER RIGHT';
                case 135
                    quadName = 'UPPER LEFT';
                case 225
                    quadName = 'LOWER LEFT';
                case 315
                    quadName = 'LOWER RIGHT';
            end

            % Format condition name for display
            if currentCondition == 1
                condDisplay = 'CENTRAL CUE';
            else
                condDisplay = 'FLASH BL';
            end

            % Build output based on condition (print before response, add PROBE after)
            if currentCondition == 1  % central cue
                if motionDir == 1
                    motionText = 'FUGAL';
                else
                    motionText = 'PETAL';
                end
                trialInfoStr = sprintf('B%d T%d: %s | %s | %s | CUE @ %.0fdva | SPEED %.0f/s | ONSET @ %.0fms', ...
                    blockIdx, trial, condDisplay, motionText, quadName, ...
                    flashEccDva_log, speedDva, flashOnsetTime_ms);
            else  % flash baseline
                trialInfoStr = sprintf('B%d T%d: %s | %s | FLASH @ %.0fdva | ONSET @ %.0fms', ...
                    blockIdx, trial, condDisplay, quadName, ...
                    flashEccDva_log, flashOnsetTime_ms);
            end

            % Brief pause before probe (frame-based). The participant sees only
            % the fixation cross, exactly as before. We ALSO exercise the probe
            % DrawTexture and the DrawFormattedText paths here, drawn invisibly
            % (probe at alpha 0; text in black on black), so the one-time texture
            % bind and font glyph-cache costs are paid during this already-present
            % flipping interval instead of landing on the first VISIBLE response
            % frame (which was the source of the first-trial glitch). Invisible
            % warm = no change to what the participant sees.
            warmRect = CenterRectOnPoint(probe.Rect, xCenter, yCenter);
            for intervalFrame = 1:probe.intervalFrames
                Screen('FillRect', window, black);
                Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                % Invisible warm-up draws (alpha 0 probe; black text on black) to
                % pre-pay the texture-bind and font glyph-cache costs. Prime the
                % SAME text and size the response phase actually uses.
                Screen('DrawTexture', window, probe.Texture, [], warmRect, 0, [], [], [grey grey grey 0]);
                Screen('TextSize', window, 28);
                DrawFormattedText(window, 'Click to confirm', 'center', yCenter + 60, black);
                Screen('Flip', window);
            end

            % Target location for probe placement depends on what's being localized
            if currentCondition == 2  % Localizing FLASH - flash is on the diagonal
                targetLocX = flashLocX;
                targetLocY = flashLocY;
            else  % Localizing MOVING STIMULUS - stimulus position on trajectory when cued
                targetLocX = stimLocAtCueX;
                targetLocY = stimLocAtCueY;
            end

            % Target DVA is ALWAYS flashEccDva - the base eccentricity
            targetDva = flashEccDva;

            %----------------------------------------------------------
            % DEFINE THE RESPONSE TRACK (this trial's trajectory)
            %----------------------------------------------------------
            % The probe is locked to the radial diagonal that the stimulus/flash
            % travelled on, running from fixation (centre) out to the screen
            % edge. Both conditions share this line because the flash now sits
            % directly on the diagonal.
            %
            % Unit vector pointing OUTWARD along the trajectory:
            trackUX = phaseshiftFactorX * sin45;   % +/- 0.7071
            trackUY = phaseshiftFactorY * cos45;   % +/- 0.7071  (screen coords)

            % Inner endpoint = fixation; outer endpoint = the farthest the probe
            % can sit on this diagonal with its WHOLE disk on-screen. The margin
            % includes the probe radius plus a few px, so the disk edge (not just
            % its centre) stays inside the display at maximum extent.
            margin = probe.SizePix/2 + 4;
            if trackUX > 0
                tX = (windowRect(3) - margin - xCenter) / trackUX;
            else
                tX = (margin - xCenter) / trackUX;
            end
            if trackUY > 0
                tY = (windowRect(4) - margin - yCenter) / trackUY;
            else
                tY = (margin - yCenter) / trackUY;
            end
            trackMaxT = min(tX, tY);            % outward extent in pixels (probe on-screen)
            trackMinT = 0;                      % fixation end

            % Probe start position - randomised to ONE END of THIS trajectory:
            % fixation (centre) half the time, a fixed outer point the rest.
            % The outer point is 22 DVA from fixation, clamped to trackMaxT if
            % that would run the probe off-screen on this diagonal (so it lands
            % at the on-screen maximum, ~19 DVA, instead).
            edgeStartDva = 22;
            edgeStartT   = dva2pix(edgeStartDva, eyeScreenDistance, windowRect, screenHeight);
            edgeStartT   = min(edgeStartT, trackMaxT);   % keep whole probe on-screen

            if probeStartsAtFixation
                probeStartX = xCenter;
                probeStartY = yCenter;
                probeInitialText = 'centre';
            else
                probeStartX = xCenter + trackUX * edgeStartT;
                probeStartY = yCenter + trackUY * edgeStartT;
                probeInitialText = 'edge';
            end

            % Setup response phase.
            % DELTA-ALONG-TRACK tracking (1D track lock). The probe is driven
            % by mouse MOVEMENT (GetMouse valuator deltas - the hardware
            % cursor is detached and frozen off at the screen edge) projected
            % onto the track. t = scalar distance along the outward track
            % unit vector (pixels), initialised from this trial's probe
            % start, then advanced by the on-track component of each delta at
            % 1:1 gain.
            trackT = (probeStartX - xCenter) * trackUX + (probeStartY - yCenter) * trackUY;
            trackT = max(trackMinT, min(trackMaxT, trackT));

            % Flush deltas accumulated since the last GetMouse call anywhere
            % in the script, so no stale motion (e.g. the mouse nudged during
            % the stimulus) jumps the probe at onset.
            [~, ~, ~, ~, ~] = GetMouse(window);

            probeX = xCenter + trackUX * trackT;
            probeY = yCenter + trackUY * trackT;

            % Flush keyboard state before entering response loop
            KbReleaseWait();

            % Response loop - delta (relative) mouse motion
            respToBeMade = true;
            repeatTrialRequested = false;
            clickTime = NaN;   % set on click; stays NaN if trial exited via R-key

            % Track probe stillness for dynamic text color
            lastProbeT = trackT;
            mouseStillSince = GetSecs();
            mouseStillThreshold = 0.6;  % probe must be held still this long (s) before confirm is offered
            hasMovedProbe = false;  % Must move probe before it can turn white

            % Confirm prompt text size (shown near fixation only when the probe
            % is held still). Set once here rather than every frame.
            Screen('TextSize', window, 28);

            while respToBeMade
                HideCursor(screenNumber);   % belt-and-braces; cursor is frozen at the edge anyway

                % Single time read per frame, reused for all stillness checks
                % below (avoids 2-3 GetSecs calls on the response hot path).
                nowSecs = GetSecs();

                % Single mouse read per frame: buttons for the confirm click,
                % raw-delta valuators for motion.
                [~, ~, buttons, ~, valuators] = GetMouse(window);
                dRawX = valuators(1);
                dRawY = valuators(2);

                % Project the MOVEMENT delta onto the outward track unit vector
                % (1:1 gain) and advance the track scalar.
                dT = dRawX * trackUX + dRawY * trackUY;
                trackT = trackT + dT;
                trackT = max(trackMinT, min(trackMaxT, trackT));

                % On-track probe position
                probeX = xCenter + trackUX * trackT;
                probeY = yCenter + trackUY * trackT;

                % Check if probe has moved along the track - update stillness timer
                if abs(trackT - lastProbeT) > 1
                    mouseStillSince = nowSecs;
                    lastProbeT = trackT;
                    hasMovedProbe = true;  % Mark that probe has been moved
                end

                % Single stillness test, reused for probe colour AND prompt text
                % below (was evaluated twice with two separate GetSecs reads).
                probeIsStill = hasMovedProbe && (nowSecs - mouseStillSince) >= mouseStillThreshold;

                % Determine text and probe color based on stillness (only after movement)
                if probeIsStill
                    confirmTextColor = white;  % Mouse still for mouseStillThreshold+
                    probeColorMod = [255 255 255];  % Bright white probe
                else
                    confirmTextColor = grey;   % Mouse moving or hasn't moved yet
                    probeColorMod = [grey grey grey];  % Grey probe
                end

                % Draw
                Screen('FillRect', window, black);
                Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                % Both conditions localize a 1 dva disk, so use the same disk probe.
                probeDestRect = CenterRectOnPoint(probe.Rect, probeX, probeY);
                Screen('DrawTexture', window, probe.Texture, [], probeDestRect, 0, [], [], probeColorMod);

                % Show ONLY the confirmation prompt, and only once the probe is
                % held still. No task reminder during movement (it was a source
                % of peripheral text near the response). Placed just below
                % fixation so it is central and easy to read.
                if probeIsStill
                    DrawFormattedText(window, 'Click to confirm', 'center', ...
                        yCenter + 60, confirmTextColor);
                end
                Screen('Flip', window);

                % Confirm click. 'buttons' MUST come from the top-of-frame
                % GetMouse: a second GetMouse here would consume the valuator
                % deltas accrued during the flip wait and make the probe sluggish.
                if any(buttons)
                    clickTime = GetSecs();   % for RT (flash onset -> click)
                    % Play subtle tick sound for confirmation
                    try
                        PsychPortAudio('Stop', pahandle_tick);
                        PsychPortAudio('Start', pahandle_tick, 1, 0, 0);
                    catch
                    end
                    respToBeMade = false;
                end

                % Check keys (R = repeat trial, ESC = quit, SPACE = end practice)
                [~, ~, keyCode] = KbCheck();
                if keyCode(rKey)
                    repeatTrialRequested = true;
                    respToBeMade = false;
                elseif isPractice && keyCode(spaceKey)
                    % End practice from the response phase: abandon this trial's
                    % response (nothing is logged in practice anyway) and leave.
                    practiceSkipRequested = true;
                    respToBeMade = false;
                elseif keyCode(escapeKey)
                    if confirmQuit()
                        quitCleanup(csv_filepath, csv_data, csv_header, timing_pdf_filepath, ...
                            allFrameIntervalsMs, csv_filename, sbjname, time_start, refreshRate, ...
                            ifi, measuredRefreshRate, csv_trial_counter, numBlocks, ...
                            originalAlertVolume, isEyelink);
                        return;
                    end
                    KbReleaseWait();
                    HideCursor(screenNumber);   % quit dialog may disturb cursor state
                end
            end

            % Wait for mouse button release before continuing
            while any(buttons)
                [~, ~, buttons] = GetMouse(window);
            end

            % Store final probe position
            finalProbeCenterX = probeX;
            finalProbeCenterY = probeY;

            % If repeat requested, skip data storage and re-run this trial immediately
            if repeatTrialRequested
                fprintf('Trial %d: INVALIDATED - Repeat requested by experimenter (R key)\n', trial);
                continue;  % Skip to next iteration - trial number stays same, same trial params used
            end

            % SPACE ended the practice block from the response phase: leave now,
            % skipping the blank, the logging block and the ITI.
            if practiceSkipRequested
                break;
            end

            % 0.75 s blank (black) screen after a confirmed response, before the
            % next trial's fixation cross / countdown appears. Only reached on
            % a genuine click: R-key repeats (above) and gaze-invalid trials
            % (which never enter this response branch) both bail out earlier, so
            % neither gets this pause.
            %
            % FRAME-LOCKED, not a single Flip + WaitSecs. A one-shot flip
            % followed by a long WaitSecs leaves the display with no flips for
            % most of a second; PTB's Vulkan backend then times out waiting on
            % vkWaitForPresentKHR for the onset timestamp and spams
            % "Failed to retrieve visual stimulus onset timestamp". Flipping
            % every frame keeps the present queue alive - the same rationale the
            % instruction screen, the ITI and the pre-probe pause already use.
            postResponseBlankDur = 0.75;   % seconds
            blankFrames = round(postResponseBlankDur * refreshRate);
            for blankFrame = 1:blankFrames
                Screen('FillRect', window, black);
                Screen('Flip', window);
            end

            % Probe is LOCKED to the trajectory, so it can never leave the
            % correct quadrant; no quadrant-validity check is needed.

            % Calculate final probe position as ACTUAL Euclidean distance from fixation
            finalProbeDistPix = sqrt((finalProbeCenterX - xCenter)^2 + (finalProbeCenterY - yCenter)^2);

            % Convert final probe distance to DVA
            probeDisplayDva = pix2dva(finalProbeDistPix, eyeScreenDistance, windowRect, screenHeight);

            % OFFSET = final probe position - target position (probe minus target)
            totalOffsetDva = probeDisplayDva - targetDva;

            % Print complete trial info on single line (values match CSV columns)
            fprintf('%s | TARGET: %.2f | INIT: %s | PROBE: %.2f | OFFSET: %+.2f dva\n', ...
                trialInfoStr, targetDva, probeInitialText, probeDisplayDva, totalOffsetDva);
        end

        %--------------------------------------------------------------
        %                STORE TRIAL DATA
        %--------------------------------------------------------------
        % Log ALL trials to CSV (valid and invalid) - EXCEPT practice trials,
        % which are never written and never advance the valid-trial counter.

        % Determine if trial is valid (probe is locked to track, so the only
        % invalidation is a gaze/fixation violation during the stimulus).
        trialIsValid = ~gazeViolationDuringMotion;

        if trialIsValid && ~isPractice
            csv_trial_counter = csv_trial_counter + 1;
            trial_identifier = csv_trial_counter;
        else
            trial_identifier = NaN;   % numeric NaN, matching the valid-trial
                                      % numbers (writetable requires
                                      % type-homogeneous cell columns)
        end

        % Convert values to text for CSV
        if motionDir == 1
            motionText = 'fugal';
        elseif motionDir == -1
            motionText = 'petal';
        else
            motionText = 'none';
        end

        if quad == 45
            quadText = 'upper_right';
        elseif quad == 135
            quadText = 'upper_left';
        elseif quad == 225
            quadText = 'lower_left';
        else
            quadText = 'lower_right';
        end

        if gazeViolationDuringMotion
            validText = 'invalid_fixation';
        else
            validText = 'valid';
        end

        % Calculate timing info
        flashOnsetTime_ms = ((flashOnsetFrame - 1) / refreshRate) * 1000;   % frame f flips (f-1)*ifi after sweep start

        if trialIsValid
            targetDva_csv = targetDva;  % Theoretical DVA (exact value)
            % Convert target position to DVA (signed: negative = left/up of center)
            targetX_csv = pix2dva(abs(targetLocX - xCenter), eyeScreenDistance, windowRect, screenHeight) * sign(targetLocX - xCenter);
            targetY_csv = -pix2dva(abs(targetLocY - yCenter), eyeScreenDistance, windowRect, screenHeight) * sign(targetLocY - yCenter);  % Flip: screen Y down = negative DVA
            probeInitial_csv = probeInitialText;
            probeDva_csv = probeDisplayDva;  % Final position (converted from pixels)
            % Convert probe position to DVA (signed: negative = left/up of center)
            probeX_csv = pix2dva(abs(finalProbeCenterX - xCenter), eyeScreenDistance, windowRect, screenHeight) * sign(finalProbeCenterX - xCenter);
            probeY_csv = -pix2dva(abs(finalProbeCenterY - yCenter), eyeScreenDistance, windowRect, screenHeight) * sign(finalProbeCenterY - yCenter);  % Flip: screen Y down = negative DVA
            fovealOffset_csv = totalOffsetDva;  % Probe distance from fixation - target distance from fixation
            % Calculate x and y offsets in DVA (probe center - target center)
            xOffsetPix = finalProbeCenterX - targetLocX;
            yOffsetPix = finalProbeCenterY - targetLocY;
            xOffset_csv = pix2dva(abs(xOffsetPix), eyeScreenDistance, windowRect, screenHeight) * sign(xOffsetPix);
            yOffset_csv = -pix2dva(abs(yOffsetPix), eyeScreenDistance, windowRect, screenHeight) * sign(yOffsetPix);  % Flip sign: screen Y increases downward

            % Response time: flash onset -> confirmation click (ms). Both
            % conditions (static flash has an onset too). NaN if either the
            % flash-onset timestamp or the click was not captured (e.g. R-key).
            if ~isnan(flashOnsetVBL) && ~isnan(clickTime)
                rt_csv = (clickTime - flashOnsetVBL) * 1000;
            else
                rt_csv = NaN;
            end

            % Temporal error (ms): convert the spatial setting into a time by
            % asking when the stimulus was at the indicated position, minus flash
            % time. = signed along-track offset (in the motion direction) / speed.
            %   signed offset = fovealOffset (radial probe - target) * motionDir
            %     fugal  (motionDir=+1, outward): ahead = larger radius  -> +ve
            %     petal  (motionDir=-1, inward):  ahead = smaller radius -> +ve
            %   +ve temporal error = stimulus localized AHEAD of (later than) flash.
            % NA for static (no speed / no position<->time mapping).
            if currentCondition == 1 && ~isnan(speedDva) && speedDva > 0
                signedOffsetDva = fovealOffset_csv * motionDir;
                temporalError_csv = (signedOffsetDva / speedDva) * 1000;
            else
                temporalError_csv = NaN;
            end
        else
            % For invalid trials (gaze violation or wrong quadrant), set probe values to NaN
            targetDva_csv = targetDva;  % Keep target info for reference
            targetX_csv = NaN;
            targetY_csv = NaN;
            probeInitial_csv = 'NA';  % char, matching 'centre'/'edge'
            probeDva_csv = NaN;
            probeX_csv = NaN;
            probeY_csv = NaN;
            fovealOffset_csv = NaN;
            xOffset_csv = NaN;
            yOffset_csv = NaN;
            rt_csv = NaN;
            temporalError_csv = NaN;
        end

        % Row order matches csv_header exactly (defined at INITIALIZE DATA
        % STORAGE). Keep every column type-homogeneous across valid/invalid
        % rows or writetable will refuse to save.
        % PRACTICE trials are skipped entirely here: no row is appended and
        % csvDirty is left untouched, so nothing from the practice block can
        % reach the CSV.
        if ~isPractice
            speedDva_csv = speedDva;  % NaN for static (flash baseline)
            csv_data = [csv_data; {expInfo.version, blockIdx, trial_identifier, currentConditionName, validText, ...
                motionText, quadText, eccDva, speedDva_csv, ...
                flashOnsetFrame, flashOnsetTime_ms, flashFrameCounter, ...
                targetDva_csv, targetX_csv, targetY_csv, probeInitial_csv, probeDva_csv, probeX_csv, probeY_csv, ...
                fovealOffset_csv, temporalError_csv, xOffset_csv, yOffset_csv, ...
                measuredFps, stimSkippedFrames, stimMeanFrameMs, ...
                stimWorstFrameMs, stimDurErrorMs, cueOnsetErrorMs, ...
                rt_csv, expInfo.rngSeed}];

            % INCREMENTAL SAVE policy: we no longer rewrite the entire CSV after
            % every trial (that was an O(n^2) full re-serialisation of all rows so
            % far, growing to a 380-row rewrite by session end and adding unbounded
            % dead time between trials). Instead we mark data dirty and flush once
            % per block (and once at session end / on any exit). Worst-case loss on
            % a hard crash is the current partial block, which is acceptable.
            csvDirty = true;
        end

        %==============================================================
        %   PROCESS INVALID TRIALS QUEUE - CHECK AFTER EACH TRIAL
        %==============================================================
        if trial >= numTrialsThisBlock && ~isempty(invalidTrialsQueue)
            fprintf('\n*** Processing %d queued repeat trials ***\n', length(invalidTrialsQueue));
            for q = 1:length(invalidTrialsQueue)
                qt = invalidTrialsQueue(q);
                if qt.attemptCount <= maxRepeatAttempts
                    newRow = [qt.cond, qt.quad, qt.motionDir, qt.eccDva, qt.speedDva];
                    trials = [trials; newRow];
                    trialAttemptCount = [trialAttemptCount, qt.attemptCount];
                end
            end
            numTrialsThisBlock = size(trials, 1);
            invalidTrialsQueue = [];
        end

        %--------------------------------------------------------------
        %                INTER-TRIAL INTERVAL (fixation maintained)
        %--------------------------------------------------------------
        % SKIPPED after the last trial of the block: the cross would otherwise
        % flash for 200 ms between the post-response blank and the rest screen.
        % This check sits AFTER the invalid-trials queue block above, so
        % numTrialsThisBlock already includes any trials appended for repeat -
        % i.e. "last trial" means the genuinely final one of the block.
        isLastTrialOfBlock = (trial >= numTrialsThisBlock);
        if ~isLastTrialOfBlock
            itiFrames = round(0.2 * refreshRate);  % 200ms ITI
            for itiFrame = 1:itiFrames
                Screen('FillRect', window, black);
                Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                Screen('Flip', window);
            end
        end

        % Increment trial counter
        trial = trial + 1;

    end  % End trial while loop

    % -------- BLOCK-END CSV FLUSH (crash-safe granularity) --------
    % Write accumulated rows to disk once per block instead of once per trial.
    % A hard crash now costs at most the current block, not a single trial,
    % while removing the per-trial full-file rewrite from the hot path.
    if csvDirty
        local_flushCSV(csv_filepath, csv_data, csv_header);
        csvDirty = false;
    end

    %------------------------------------------------------------------
    %------------------------------------------------------------------
    %          END OF PRACTICE -> "CLICK ANYWHERE TO BEGIN EXPERIMENT"
    %------------------------------------------------------------------
    % Reached either because every practice trial ran or because SPACE was
    % pressed. From the click onward the real experiment starts at block 1
    % and every trial is logged exactly as before. Flipped every iteration to
    % keep the flip cadence alive during this indefinite wait (same rationale
    % as the instruction and rest screens).
    if isPractice
        if practiceSkipRequested
            practiceEndReason = 'ended early with SPACE';
        else
            practiceEndReason = 'all practice trials completed';
        end
        fprintf('=== PRACTICE BLOCK ENDED (%s) - no data logged ===\n\n', practiceEndReason);

        Screen('TextSize', window, 50);
        KbReleaseWait();
        practiceWaiting = true;
        while practiceWaiting
            HideCursor(screenNumber);
            Screen('FillRect', window, black);
            DrawFormattedText(window, 'Click anywhere to begin experiment', ...
                'center', 'center', white);
            Screen('Flip', window);

            [~, ~, pracButtons] = GetMouse(window);
            if any(pracButtons)
                practiceWaiting = false;
            end
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyIsDown && keyCode(escapeKey)
                if confirmQuit()
                    quitCleanup(csv_filepath, csv_data, csv_header, timing_pdf_filepath, ...
                        allFrameIntervalsMs, csv_filename, sbjname, time_start, refreshRate, ...
                        ifi, measuredRefreshRate, csv_trial_counter, numBlocks, ...
                        originalAlertVolume, isEyelink);
                    return;
                end
                KbReleaseWait();
            end
        end
        while any(pracButtons)   % wait for click release
            [~, ~, pracButtons] = GetMouse(window);
        end
        KbReleaseWait();
    end

    %------------------------------------------------------------------
    %------------------------------------------------------------------
    %                    REST SCREEN BETWEEN BLOCKS
    %------------------------------------------------------------------
    if ~isPractice && blockIdx < numBlocks
        progressPercent = round(100 * blockIdx / numBlocks);

        % Progress BAR is drawn ONLY at the quartile milestones (~25/50/75/
        % 100% complete). At every other block break the break prompt, the
        % "Resuming in N seconds" countdown and the "Block X of Y complete"
        % heading still appear - just without the bar. Nearest-block matching
        % handles block counts that don't split evenly into quarters. (100%
        % maps to the final block, which has no rest screen, so in practice
        % the bar surfaces at roughly 25/50/75%.)
        blockFractions  = (1:numBlocks) / numBlocks;
        quartileFracs   = [0.25 0.50 0.75 1.00];
        milestoneBlocks = zeros(1, numel(quartileFracs));
        for qi = 1:numel(quartileFracs)
            [~, milestoneBlocks(qi)] = min(abs(blockFractions - quartileFracs(qi)));
        end
        showProgressBar = ismember(blockIdx, milestoneBlocks);

        restDuration = 20;   % seconds of mandatory rest
        restStartTime = GetSecs();

        % Fixed vertical layout, TOP TO BOTTOM: break/click prompt -> resuming
        % countdown -> "Block X of Y complete" heading -> progress bar.
        % Bar is bigger and sits closer to screen centre than the original
        % (was a small 600x24 bar parked at yCenter+100..+124). Pill-shaped
        % (rounded ends via FillOval caps) with a visible dark track under
        % the fill so progress reads clearly even at 1/numBlocks.
        barWidth  = 700;
        barHeight = 36;
        barLeft = xCenter - barWidth/2;
        barTop  = yCenter + 120;
        capRadius = barHeight / 2;
        barRect  = [barLeft, barTop, barLeft + barWidth, barTop + barHeight];
        % Fill never narrower than the bar's own height, so the rounded end
        % caps always fit inside it (matters at low block counts / early blocks).
        fillWidth = max(barHeight, barWidth * (blockIdx / numBlocks));
        fillRect  = [barLeft, barTop, barLeft + fillWidth, barTop + barHeight];
        % Track colour lightened from near-black [45 45 45] so the FULL bar
        % extent is visible against the black background even when the blue
        % fill is small (e.g. block 1 of 8 = ~13% filled) - otherwise only the
        % filled sliver was visible and it didn't read as a "bar" at all.
        % Colours are written as 0-255 intent then scaled to this window's
        % actual white point (white/255). This window is NOT in the 0-255
        % range - raw [70 70 70]/[80 130 210] values sit far above its white
        % point and clamp to solid white, which is why the track and fill
        % were indistinguishable (one white blob, no visible progress). All
        % the other colours here (white/grey/black) already track the white
        % point, so scaling by white/255 makes the bar match them and works
        % whether the window is 0-1 or 0-255.
        trackColor = [70 70 70]   / 255 * white;   % dark grey (unfilled track)
        fillColor  = [80 130 210] / 255 * white;   % blue (progress fill)
        promptTextY    = yCenter - 260;   % break / click-to-continue line
        countdownTextY = yCenter - 170;   % "Resuming in N seconds..."
        headingTextY   = yCenter + 20;    % "Block X of Y complete (Z% done)"

        KbReleaseWait();
        while true
            remainingTime = max(0, ceil(restDuration - (GetSecs() - restStartTime)));

            if remainingTime > 0
                promptLine = 'Take a short break...';
            else
                promptLine = 'Click anywhere to continue.';
            end
            Screen('FillRect', window, black);
            Screen('TextSize', window, 50);
            DrawFormattedText(window, promptLine, 'center', promptTextY, white);
            if remainingTime > 0
                DrawFormattedText(window, sprintf('Resuming in %d seconds...', remainingTime), ...
                    'center', countdownTextY, grey);
            end
            % --- Milestone-only progress display: heading + bar ---
            % Both the "Block X of Y complete" heading AND the bar appear ONLY
            % at the quartile milestones. Every other break shows just the
            % break prompt and the "Resuming in N seconds" counter above - no
            % block count, no percentage, no bar.
            if showProgressBar
                DrawFormattedText(window, sprintf('Block %d of %d complete  (%d%% done)', ...
                    blockIdx, numBlocks, progressPercent), 'center', headingTextY, white);

                % Progress bar: dark track, then blue fill, both pill-shaped.
                % Track (full-width dark pill): rect body + rounded end caps.
                Screen('FillRect', window, trackColor, barRect);
                Screen('FillOval', window, trackColor, [barLeft - capRadius, barTop, barLeft + capRadius, barTop + barHeight]);
                Screen('FillOval', window, trackColor, [barLeft + barWidth - capRadius, barTop, barLeft + barWidth + capRadius, barTop + barHeight]);
                % Fill (progress portion, drawn on top): rect body + rounded end caps.
                Screen('FillRect', window, fillColor, fillRect);
                Screen('FillOval', window, fillColor, [barLeft - capRadius, barTop, barLeft + capRadius, barTop + barHeight]);
                Screen('FillOval', window, fillColor, [barLeft + fillWidth - capRadius, barTop, barLeft + fillWidth + capRadius, barTop + barHeight]);
                % Outline around the whole pill.
                Screen('FrameRect', window, grey * 0.8, ...
                    [barLeft - capRadius, barTop, barLeft + barWidth + capRadius, barTop + barHeight], 3);
            end

            Screen('Flip', window);

            % Click to continue (consistent with the start screen; only after
            % the countdown). ESC still quits.
            [~, ~, restButtons] = GetMouse(window);
            if remainingTime <= 0 && any(restButtons)
                break;
            end
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyIsDown && keyCode(escapeKey)
                if confirmQuit()
                    quitCleanup(csv_filepath, csv_data, csv_header, timing_pdf_filepath, ...
                        allFrameIntervalsMs, csv_filename, sbjname, time_start, refreshRate, ...
                        ifi, measuredRefreshRate, csv_trial_counter, numBlocks, ...
                        originalAlertVolume, isEyelink);
                    return;
                end
                KbReleaseWait();
            end
        end
        while any(restButtons)   % wait for click release
            [~, ~, restButtons] = GetMouse(window);
        end
        KbReleaseWait();
    end

end  % End block loop

%======================================================================
%%                    EXPERIMENT COMPLETE
%======================================================================

% Play success sound (non-blocking) and show the completion message for 3 s.
try
    PsychPortAudio('Start', pahandle_correcto, 1, 0, 0);
catch
end

completionText = 'Experiment Complete!\n\nThank you for participating.';
Screen('TextSize', window, 50);
for endFrame = 1:round(3 * refreshRate)
    Screen('FillRect', window, black);
    DrawFormattedText(window, completionText, 'center', 'center', white);
    Screen('Flip', window);
end

%----------------------------------------------------------------------
%%                    SAVE DATA (Final save - data already saved incrementally)
%----------------------------------------------------------------------

% Final save via the shared, error-safe flush (the timing-report section
% below flushes again; both are cheap and idempotent).
local_flushCSV(csv_filepath, csv_data, csv_header);
fprintf('\nData saved to: %s\n', csv_filepath);

% Print summary
fprintf('\n=== EXPERIMENT SUMMARY ===\n');
fprintf('Valid trials: %d   Blocks: %d\n', csv_trial_counter, numBlocks);

% Quick console frame-health glance (full detail is in the PDF timing report)
try
    skipCol  = cell2mat(csv_data(:, strcmp(csv_header, 'stim_skipped_frames')));
    worstCol = cell2mat(csv_data(:, strcmp(csv_header, 'stim_worst_frame_ms')));
    fprintf('Frame health: %d trials with a skipped frame, worst frame %.1f ms (ideal %.2f ms)\n', ...
        sum(skipCol > 0, 'omitnan'), max(worstCol, [], 'omitnan'), ifi*1000);
catch
end

%----------------------------------------------------------------------
%%             TIMING REPORT (PDF): frame-length histogram + stats
%----------------------------------------------------------------------
% Written via the shared local function so it is also produced on any early
% exit (ESC-quit). CSV was already flushed above.
writeTimingReport(timing_pdf_filepath, allFrameIntervalsMs, csv_data, csv_header, ...
    csv_filename, sbjname, time_start, refreshRate, ifi, measuredRefreshRate, ...
    csv_trial_counter, numBlocks);


%----------------------------------------------------------------------
%%                    CLEANUP
%----------------------------------------------------------------------

if isEyelink
    Eyelink('StopRecording');
    Eyelink('CloseFile');
    try
        Eyelink('ReceiveFile', constants.eyelink_data_fname, constants.eyelink_data_path);
    catch
        fprintf('Warning: Could not retrieve EDF file\n');
    end
    Eyelink('Shutdown');
end

Priority(0);  % Reset priority to normal
PsychPortAudio('Close');   % close all open audio handles
Screen('CloseAll');
ListenChar(0);  % Re-enable keyboard to MATLAB
% Re-attach cursor to the physical mouse (undo detachFromMouse) and show it
try SetMouse(cursorParkX, cursorParkY, screenNumber, [], 0); catch, end
ShowCursor;

% RESTORE macOS alert volume
try
    system(sprintf('osascript -e "set volume alert volume %d"', originalAlertVolume));
catch
    % If restoration fails, try setting to default
    system('osascript -e "set volume alert volume 100"');
end

fprintf('\nExperiment finished successfully!\n');

%======================================================================
%%        HELPER FUNCTION: SHARED EARLY-EXIT (ESC-QUIT) CLEANUP
%======================================================================
function quitCleanup(csv_filepath, csv_data, csv_header, timing_pdf_filepath, ...
        allFrameIntervalsMs, csv_filename, sbjname, time_start, refreshRate, ...
        ifi, measuredRefreshRate, csv_trial_counter, numBlocks, ...
        originalAlertVolume, isEyelink)
    % Single shared ESC-quit path: flush data, write the timing report, and
    % restore EVERYTHING the experiment changed (keyboard capture, cursor,
    % priority, audio, macOS alert volume, EyeLink). NOTE: the EDF file is
    % closed on the tracker host but NOT transferred on an early quit; retrieve
    % it manually from the host PC if needed.
    local_flushCSV(csv_filepath, csv_data, csv_header);
    writeTimingReport(timing_pdf_filepath, allFrameIntervalsMs, csv_data, csv_header, ...
        csv_filename, sbjname, time_start, refreshRate, ifi, measuredRefreshRate, ...
        csv_trial_counter, numBlocks);
    if isEyelink
        try
            Eyelink('StopRecording');
            Eyelink('CloseFile');
            Eyelink('Shutdown');
        catch
        end
    end
    Priority(0);
    try PsychPortAudio('Close'); catch, end   % close all audio handles
    ListenChar(0);
    % Re-attach cursor to the physical mouse (undo detachFromMouse) and show it
    try SetMouse(500, 500, 0, [], 0); catch, end
    ShowCursor;
    sca;
    try
        system(sprintf('osascript -e "set volume alert volume %d"', originalAlertVolume));
    catch
    end
end

%======================================================================
%%        HELPER FUNCTION: WRITE TIMING REPORT (PDF)
%======================================================================
function writeTimingReport(pdfPath, allFrameIntervalsMs, csv_data, csv_header, ...
        csv_filename, sbjname, time_start, refreshRate, ifi, measuredRefreshRate, ...
        nValidTrials, numBlocks)
    % Build the per-session timing report (frame-length histogram to the
    % nearest ms + summary stats) and save as PDF. Safe to call on the normal
    % end of the session OR on any early exit. Fully wrapped so it can never
    % throw into the caller (which may be mid-cleanup after an ESC quit).
    try
        if isempty(csv_data)
            fprintf('(Timing report skipped: no trials recorded yet.)\n');
            return;
        end

        % Columns needed (guard each so a missing column can't abort the report)
        getCol = @(name) cell2mat(csv_data(:, strcmp(csv_header, name)));
        fpsCol     = getCol('measured_fps');
        skipCol    = getCol('stim_skipped_frames');
        meanMsCol  = getCol('stim_mean_frame_ms');
        worstCol   = getCol('stim_worst_frame_ms');
        durErrCol  = getCol('stim_dur_error_ms');
        onsetErrCol= getCol('cue_onset_error_ms');

        % Script version + RNG seed: constant per session, so read from row 1.
        % Guarded so a CSV from an older script (without the columns) still
        % produces a report.
        verStr = 'n/a'; seedStr = 'n/a';
        try verStr = csv_data{1, strcmp(csv_header, 'version')}; catch, end
        try seedStr = sprintf('%u', csv_data{1, strcmp(csv_header, 'rng_seed')}); catch, end

        fh = figure('Visible', 'off', 'Units', 'centimeters', ...
                    'Position', [2 2 21 27], 'Color', 'w', ...
                    'PaperUnits', 'centimeters', 'PaperSize', [21 29.7], ...
                    'PaperPositionMode', 'auto');

        % --- Top: frame-length histogram ---
        ax1 = subplot(2, 1, 1, 'Parent', fh);
        if ~isempty(allFrameIntervalsMs)
            fi = allFrameIntervalsMs;
            idealMs = ifi * 1000;
            % 0.1 ms bins, spanning at least ideal +/- 1 ms so the ideal line and
            % the (usually tight) distribution are both always visible. Finer than
            % 1 ms because a healthy session's frames cluster within a few tenths
            % of a ms of ideal - 1 ms bins collapse them all into one bar.
            lo = min(floor(min(fi)*10)/10, idealMs - 1);
            hi = max(ceil(max(fi)*10)/10,  idealMs + 1);
            edges = lo:0.1:hi;
            histogram(ax1, fi, edges, 'FaceColor', [0.2 0.4 0.7], 'EdgeColor', 'none');
            hold(ax1, 'on');
            yl = ylim(ax1);
            plot(ax1, [idealMs idealMs], yl, 'r--', 'LineWidth', 1.5);
            text(ax1, idealMs, yl(2)*0.95, sprintf('  ideal %.2f ms', idealMs), ...
                'Color', 'r', 'VerticalAlignment', 'top');
            hold(ax1, 'off');
            xlabel(ax1, 'Frame length (ms, 0.1 ms bins)');
            ylabel(ax1, 'Count');
            title(ax1, sprintf('Frame-length distribution  (n = %d frames)', numel(fi)));
            % Linear y-axis from 0 so a single dominant bar renders full-height
            % (on a log axis a lone bar sits between two near-equal limits and is
            % effectively invisible - the cause of the "no bar" report).
            ylim(ax1, [0 yl(2)*1.05]);
            grid(ax1, 'on');
        else
            text(0.5, 0.5, 'No frame intervals recorded', 'Parent', ax1, ...
                'HorizontalAlignment', 'center');
            axis(ax1, 'off');
        end

        % --- Bottom: summary stats as text ---
        ax2 = subplot(2, 1, 2, 'Parent', fh);
        axis(ax2, 'off');
        pctOver = NaN; pctMuchOver = NaN;
        if ~isempty(allFrameIntervalsMs)
            pctOver     = 100 * mean(allFrameIntervalsMs > 1.5*ifi*1000);
            pctMuchOver = 100 * mean(allFrameIntervalsMs > 2.0*ifi*1000);
        end
        lines = {
            sprintf('FLE E3 - Timing report')
            sprintf('File: %s', csv_filename)
            sprintf('Subject: %s    Date: %04d-%02d-%02d %02d:%02d', sbjname, ...
                time_start(1), time_start(2), time_start(3), time_start(4), time_start(5))
            sprintf('Script version: %s    RNG seed: %s', verStr, seedStr)
            ''
            sprintf('Expected refresh: %d Hz   (ideal frame = %.3f ms)', refreshRate, ifi*1000)
            sprintf('Measured refresh at startup: %d Hz', measuredRefreshRate)
            sprintf('Valid trials: %d    Blocks: %d', nValidTrials, numBlocks)
            ''
            sprintf('Median measured FPS across trials: %.2f Hz', median(fpsCol, 'omitnan'))
            sprintf('Mean frame duration across trials: %.3f ms', mean(meanMsCol, 'omitnan'))
            sprintf('Worst single frame (any trial): %.2f ms', max(worstCol, [], 'omitnan'))
            sprintf('Frames > 1.5x ideal: %.3f %%    > 2x ideal: %.3f %%', pctOver, pctMuchOver)
            sprintf('Trials with >=1 skipped frame: %d / %d', sum(skipCol>0,'omitnan'), numel(skipCol))
            sprintf('Total skipped frames: %d', sum(skipCol, 'omitnan'))
            ''
            sprintf('Stim duration error: mean %.2f ms, max |%.2f| ms', ...
                mean(durErrCol,'omitnan'), max(abs(durErrCol),[],'omitnan'))
            sprintf('Cue/flash onset error: mean %.2f ms, max |%.2f| ms', ...
                mean(onsetErrCol,'omitnan'), max(abs(onsetErrCol),[],'omitnan'))
            ''
            sprintf('(Histogram and skip/worst stats exclude each trial''s first')
            sprintf(' frame, which carries one-time setup cost and is not a drop.)')
        };
        text(ax2, 0.0, 1.0, lines, 'Units', 'normalized', ...
            'VerticalAlignment', 'top', 'FontName', 'FixedWidth', 'FontSize', 10, ...
            'Interpreter', 'none');

        % Export to PDF
        try
            exportgraphics(fh, pdfPath);                 % R2020a+
        catch
            print(fh, pdfPath, '-dpdf', '-bestfit');     % older MATLAB
        end
        close(fh);
        fprintf('Timing report saved to: %s\n', pdfPath);
    catch ME
        fprintf('(Timing report generation failed: %s)\n', ME.message);
        if exist('fh', 'var') && ishandle(fh), close(fh); end
    end
end

%======================================================================
%%                    HELPER FUNCTION: CONFIRM QUIT DIALOG
%======================================================================
function shouldQuit = confirmQuitDialog(window, white, grey, black)
    % Display confirmation dialog and return true if user confirms quit
    Screen('FillRect', window, black);
    Screen('TextSize', window, 50);
    DrawFormattedText(window, 'Are you sure you want to quit?\n\n [Y]      [N]', ...
        'center', 'center', white);
    Screen('Flip', window);

    KbReleaseWait();
    shouldQuit = false;
    waiting = true;
    while waiting
        [keyIsDown, ~, keyCode] = KbCheck();
        if keyIsDown
            if keyCode(KbName('y'))
                shouldQuit = true;
                waiting = false;
            elseif keyCode(KbName('n')) || keyCode(KbName('ESCAPE'))
                shouldQuit = false;
                waiting = false;
            end
        end
    end
    KbReleaseWait();
end

%======================================================================
%%        HELPER FUNCTION: WITHIN-BLOCK-BALANCED QUADRANT COLUMN
%======================================================================
function col = local_balancedQuadColumn(quadVals, nTrials, nBlocks)
    % Returns an nTrials x 1 column of quadrant values that is balanced as
    % evenly as possible WITHIN each block, then shuffled within each block.
    % Quadrant is balanced (not crossed as an experimental factor).
    %   quadVals : row/col vector of the quadrant codes (e.g. [45 135 225 315])
    %   nTrials  : total trials to fill
    %   nBlocks  : number of equal-size blocks nTrials splits into
    quadVals = quadVals(:);
    nQ = numel(quadVals);
    perBlock = nTrials / nBlocks;
    assert(mod(nTrials, nBlocks) == 0, 'nTrials must divide evenly by nBlocks.');

    col = zeros(nTrials, 1);
    for b = 1:nBlocks
        idx = (b-1)*perBlock + (1:perBlock);
        % Tile the quadrant set to fill the block as evenly as possible.
        reps = ceil(perBlock / nQ);
        pool = repmat(quadVals, reps, 1);
        pool = pool(1:perBlock);          % trim any remainder
        pool = pool(randperm(perBlock));  % shuffle within block
        col(idx) = pool;
    end
end

%======================================================================
%%        HELPER FUNCTION: PICK k ROW INDICES FROM n (PRACTICE SAMPLING)
%======================================================================
function idx = local_samplePick(n, k)
    % Returns k row indices drawn from 1:n. Without replacement when k <= n
    % (the normal case for a short practice block); if k > n it tiles whole
    % permutations and trims, so no row repeats more than necessary.
    if k <= 0
        idx = zeros(0, 1);
        return;
    end
    if k <= n
        p = randperm(n, k);
    else
        p = [];
        while numel(p) < k
            p = [p, randperm(n)];
        end
        p = p(1:k);
    end
    idx = p(:);
end

%======================================================================
%%        HELPER FUNCTION: BUILD AN ANTI-ALIASED DISK RGBA IMAGE
%======================================================================
function img = local_makeDisk(diamPix, colorRGB, white)
    % Returns an NxNx4 RGBA image of a filled, anti-aliased disk.
    %   diamPix  : disk diameter in pixels (disk fills the square canvas)
    %   colorRGB : 1x3 fill colour in [0..white]
    %   white    : the display's white index (max channel value)
    %
    % Alpha is 1 inside the disk, 0 outside, with a 1-pixel smooth edge for
    % anti-aliasing. Requires alpha blending to be enabled when drawn.
    n = max(2, round(diamPix));
    r = n / 2;
    [xx, yy] = meshgrid(1:n, 1:n);
    dist = sqrt((xx - (r + 0.5)).^2 + (yy - (r + 0.5)).^2);

    % Smooth 1-pixel falloff at the circle boundary (anti-alias)
    alpha = max(0, min(1, (r - dist) + 0.5));

    img = zeros(n, n, 4);
    img(:, :, 1) = colorRGB(1);
    img(:, :, 2) = colorRGB(2);
    img(:, :, 3) = colorRGB(3);
    img(:, :, 4) = alpha * white;   % alpha channel scaled to [0..white]
end
%======================================================================
%%        HELPER FUNCTION: FLUSH CSV TO DISK (block-level, crash-safe)
%======================================================================
function local_flushCSV(csv_filepath, csv_data, csv_header)
    % Write the accumulated trial rows to disk as a single table. Called at
    % block boundaries and on every exit path (NOT per trial), so the file is
    % rewritten roughly once per block. Fully wrapped so a write failure can
    % never throw into the caller (which may be mid-cleanup on an ESC quit).
    if isempty(csv_data)
        return;
    end
    try
        writetable(cell2table(csv_data, 'VariableNames', csv_header), csv_filepath);
    catch
        warning('Failed to save CSV data on flush - will retry at next flush.');
    end
end