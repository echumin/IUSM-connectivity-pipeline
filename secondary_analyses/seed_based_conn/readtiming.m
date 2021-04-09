function [EvtTime]=readtiming(paths,timingfile)

% Read Excel file:
[filepath,scanID,ext] = fileparts(paths.EPI);
[filepath,subjectname,ext] = fileparts(filepath);

csvfile = strcat(paths.timing,'/',subjectname,'/',timingfile);
timings = csvread(csvfile);
col33 = timings(:,33); BlkOnset = col33(col33>0);
col34 = timings(:,34); BlkDur = col34(col34>0);
nEmpty1 = 0;
nEmpty2 = 0;
nAddFuture = 0;
nRecFuture = 0;
nStills = 0;

for iloop = 1:size(BlkOnset,1)
%     disp(BlkOnset(iloop,1))
    if iloop == 2 
       disp(BlkOnset(iloop,1))
       nEmpty1 = nEmpty1 + 1;
       EvtTime.Empty1(nEmpty1).onset = BlkOnset(iloop,1);
       EvtTime.Empty1(nEmpty1).dur = BlkDur(iloop,1);
    elseif iloop == 3
       disp(BlkOnset(iloop,1))
       nAddFuture = nAddFuture + 1;
       EvtTime.AddFuture(nAddFuture).onset = BlkOnset(iloop,1);
       EvtTime.AddFuture(nAddFuture).dur = BlkDur(iloop,1);
    elseif iloop == 5
       disp(BlkOnset(iloop,1))
       nRecFuture = nRecFuture + 1;
       EvtTime.RecFuture(nRecFuture).onset = BlkOnset(iloop,1);
       EvtTime.RecFuture(nRecFuture).dur = BlkDur(iloop,1);
    elseif iloop == 4 || iloop == 6
       disp(BlkOnset(iloop,1))
       nStills = nStills + 1;
       EvtTime.Stills(nStills).onset = BlkOnset(iloop,1);
       EvtTime.Stills(nStills).dur = BlkDur(iloop,1);
    elseif iloop == 7
       disp(BlkOnset(iloop,1))
       nEmpty2 = nEmpty2 + 1;
       EvtTime.Empty2(nEmpty2).onset = BlkOnset(iloop,1);
       EvtTime.Empty2(nEmpty2).dur = BlkDur(iloop,1);
    end
end


